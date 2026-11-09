<?php

namespace App\Services;

use App\Exceptions\StoreException;
use App\Models\Entitlement;
use App\Models\Product;
use App\Models\Purchase;
use App\Services\Apple\AppleJwsException;
use App\Services\Apple\AppStoreClient;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;

/**
 * Verifica compras con la tienda, las guarda y actualiza el derecho de la instalación.
 */
class PurchaseService
{
    /** Estados de Google que dejan leer todo (si la fecha de fin no ha pasado). */
    private const PREMIUM_STATES = [
        'SUBSCRIPTION_STATE_ACTIVE',
        'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        'SUBSCRIPTION_STATE_CANCELED', // cancelada pero pagada hasta la fecha de fin
    ];

    /** Estados que la API trata como «caducada» (402 expired). */
    private const EXPIRED_STATES = [
        'SUBSCRIPTION_STATE_EXPIRED',
        'SUBSCRIPTION_STATE_ON_HOLD',
        'SUBSCRIPTION_STATE_PAUSED',
    ];

    /** Notificaciones de Apple que cambian el derecho (las demás se guardan y se ignoran). */
    public const APPLE_NOTIFICATIONS = [
        'SUBSCRIBED', 'DID_RENEW', 'DID_FAIL_TO_RENEW', 'EXPIRED', 'GRACE_PERIOD_EXPIRED', 'REFUND', 'REVOKE',
        'DID_CHANGE_RENEWAL_STATUS', 'OFFER_REDEEMED', 'DID_CHANGE_RENEWAL_PREF', 'RENEWAL_EXTENDED', 'REFUND_REVERSED',
    ];

    public function __construct(private readonly GooglePlayClient $google, private readonly AppStoreClient $apple) {}

    /**
     * Android: consulta `purchases.subscriptionsv2.get`, guarda la compra y el derecho.
     *
     * @return array{purchase: Purchase, entitlement: Entitlement, error: ?StoreException}
     */
    public function verifyGoogle(string $installId, string $productId, string $purchaseToken): array
    {
        if (! $this->google->isConfigured()) {
            throw StoreException::unavailable('Google Play no está configurado en el servidor (GOOGLE_SERVICE_ACCOUNT_JSON).');
        }
        $response = $this->google->getSubscription($purchaseToken);
        $info = $this->interpretGoogle($response, $productId);
        if ($info['lineItem'] === null) {
            throw StoreException::invalid('La compra no corresponde a este producto.');
        }

        return DB::transaction(function () use ($installId, $productId, $purchaseToken, $response, $info) {
            $purchase = Purchase::query()->firstOrNew([
                'platform' => 'android',
                'token_hash' => Purchase::hashToken($purchaseToken),
            ]);
            $purchase->fill([
                'install_id' => $installId,
                'product_id' => $productId,
                'token_encrypted' => Crypt::encryptString($purchaseToken),
            ]);
            $this->applyGoogle($purchase, $response, $info);

            $entitlement = Entitlement::query()->firstOrNew(['install_id' => $installId]);
            $this->applyPurchaseToEntitlement($entitlement, $purchase);

            if (config('mininoches.google.acknowledge')
                && ($response['acknowledgementState'] ?? null) === 'ACKNOWLEDGEMENT_STATE_PENDING'
                && $purchase->premium) {
                $this->google->acknowledge($productId, $purchaseToken);
            }

            return ['purchase' => $purchase, 'entitlement' => $entitlement, 'error' => $info['error']];
        });
    }

    /** Vuelve a consultar a Google (notificación RTDN o derecho caducado) y actualiza todos los derechos ligados. */
    public function refreshGoogle(Purchase $purchase): Purchase
    {
        $token = $purchase->token();
        if ($token === null) {
            return $purchase;
        }
        try {
            $response = $this->google->getSubscription($token);
        } catch (StoreException $e) {
            if ($e->status !== 402) {
                throw $e;
            }
            // Google ya no conoce el token (p. ej. reembolso o compra anulada): deja de ser premium.
            $purchase->fill(['state' => 'UNKNOWN_TO_STORE', 'premium' => false, 'last_verified_at' => now()])->save();
            $this->syncEntitlements($purchase);

            return $purchase;
        }
        $info = $this->interpretGoogle($response, $purchase->product_id);
        $this->applyGoogle($purchase, $response, $info);
        $this->syncEntitlements($purchase);

        return $purchase;
    }

    /**
     * iOS: consulta la transacción (GET /inApps/v1/transactions/{id}) y el estado de la suscripción
     * (GET /inApps/v1/subscriptions/{id}) en la App Store Server API, verifica cada JWS, guarda la compra por su
     * originalTransactionId (cifrado, buscado por hash) y actualiza el derecho, igual que en Android.
     *
     * @return array{purchase: Purchase, entitlement: Entitlement, error: ?StoreException}
     */
    public function verifyApple(string $installId, string $productId, string $transactionId): array
    {
        if (! $this->apple->isConfigured()) {
            throw StoreException::unavailable('La App Store no está configurada en el servidor (APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY).');
        }
        if (! ctype_digit($transactionId)) {
            throw StoreException::invalid('El transactionId de la App Store no es válido.');
        }
        if (! array_key_exists($productId, $this->appleProducts())) {
            throw StoreException::invalid('La compra no corresponde a este producto.');
        }

        $found = $this->apple->getTransaction($transactionId);
        $tx = $found['transaction'];
        $this->assertAppleTransaction($tx);
        if (($tx['productId'] ?? null) !== $productId) {
            throw StoreException::invalid('La compra no corresponde a este producto.');
        }
        $original = (string) ($tx['originalTransactionId'] ?? '');
        if (! ctype_digit($original)) {
            throw StoreException::invalid('La App Store no dio la transacción original de esta compra.');
        }
        $latest = $this->latestAppleStatus($original, $found['environment']);

        return DB::transaction(function () use ($installId, $original, $latest) {
            $purchase = Purchase::query()->firstOrNew([
                'platform' => 'ios',
                'token_hash' => Purchase::hashToken($original),
            ]);
            $purchase->fill([
                'install_id' => $installId,
                'token_encrypted' => Crypt::encryptString($original),
                'transaction_id' => null, // los id de Apple no se guardan en claro (sirven para reclamar la compra)
            ]);
            $info = $this->interpretApple($latest['status'], $latest['transaction'], $latest['renewalInfo']);
            $this->applyApple($purchase, $info, $latest['transaction'], $latest['renewalInfo'], 'api');

            $entitlement = Entitlement::query()->firstOrNew(['install_id' => $installId]);
            $this->applyPurchaseToEntitlement($entitlement, $purchase);

            return ['purchase' => $purchase, 'entitlement' => $entitlement, 'error' => $info['error']];
        });
    }

    /** Vuelve a preguntar a Apple por el estado (derecho caducado, p. ej. si se perdió la notificación de renovación). */
    public function refreshApple(Purchase $purchase): Purchase
    {
        $original = $purchase->token();
        if ($original === null || ! ctype_digit($original)) {
            return $purchase;
        }
        $env = AppStoreClient::apiEnvironment($purchase->raw_response['environment'] ?? null);
        try {
            $latest = $this->latestAppleStatus($original, $env);
        } catch (StoreException $e) {
            if ($e->status !== 402) {
                throw $e;
            }
            $purchase->fill(['state' => 'UNKNOWN_TO_STORE', 'premium' => false, 'last_verified_at' => now()])->save();
            $this->syncEntitlements($purchase);

            return $purchase;
        }
        $info = $this->interpretApple($latest['status'], $latest['transaction'], $latest['renewalInfo']);
        $this->applyApple($purchase, $info, $latest['transaction'], $latest['renewalInfo'], 'api');
        $this->syncEntitlements($purchase);

        return $purchase;
    }

    /**
     * App Store Server Notifications v2 ya verificada (signedPayload). Actualiza la compra con la transacción y la
     * renovación firmadas que trae la notificación, sin volver a llamar a Apple.
     *
     * @return array{result: string, tokenHash: ?string} resultado para guardar y hash de la transacción original
     *
     * @throws AppleJwsException si la transacción o la renovación de dentro no están bien firmadas
     */
    public function applyAppleNotification(array $payload): array
    {
        $tokenHash = null;
        $result = $this->processAppleNotification($payload, $tokenHash);

        return ['result' => $result, 'tokenHash' => $tokenHash];
    }

    private function processAppleNotification(array $payload, ?string &$tokenHash): string
    {
        $type = (string) ($payload['notificationType'] ?? '');
        $data = (array) ($payload['data'] ?? []);
        if ($type === 'TEST') {
            return 'test';
        }
        if (($data['bundleId'] ?? null) !== $this->apple->bundleId()) {
            return 'other_bundle';
        }
        if (! in_array($type, self::APPLE_NOTIFICATIONS, true)) {
            return 'ignored';
        }
        if (! is_string($data['signedTransactionInfo'] ?? null)) {
            return 'no_transaction';
        }
        $verifier = $this->apple->verifier();
        $tx = $verifier->verify($data['signedTransactionInfo']);
        $renewal = is_string($data['signedRenewalInfo'] ?? null) ? $verifier->verify($data['signedRenewalInfo']) : null;
        if (($tx['bundleId'] ?? null) !== $this->apple->bundleId()) {
            return 'other_bundle';
        }
        if (! array_key_exists((string) ($tx['productId'] ?? ''), $this->appleProducts())) {
            return 'other_product';
        }
        $original = (string) ($tx['originalTransactionId'] ?? '');
        $tokenHash = $original === '' ? null : Purchase::hashToken($original);
        $purchase = $tokenHash === null ? null
            : Purchase::query()->where('platform', 'ios')->where('token_hash', $tokenHash)->first();
        if ($purchase === null) {
            return 'unknown_purchase'; // la app aún no la presentó; se verificará cuando lo haga
        }
        $signedDate = (int) ($payload['signedDate'] ?? 0);
        if ($signedDate > 0 && $signedDate < (int) ($purchase->raw_response['signedDate'] ?? 0)) {
            return 'stale'; // llegó tarde: ya hay un estado más nuevo
        }

        $status = isset($data['status']) ? (int) $data['status'] : $this->statusFromNotification($type, (string) ($payload['subtype'] ?? ''), $tx);
        $info = $this->interpretApple($status, $tx, $renewal);
        DB::transaction(function () use ($purchase, $info, $tx, $renewal, $type, $signedDate) {
            $this->applyApple($purchase, $info, $tx, $renewal, 'notification:'.$type, $signedDate ?: null);
            $this->syncEntitlements($purchase);
        });

        return 'applied:'.$purchase->state;
    }

    /**
     * Traduce el estado de Apple al derecho. Estados de la App Store Server API: 1 activa, 2 caducada,
     * 3 reintento de cobro, 4 periodo de gracia, 5 revocada (reembolso o «Compartir en familia» retirado).
     *
     * @return array{state: string, premium: bool, trial: bool, autoRenewing: bool, expiresAt: ?CarbonImmutable, basePlan: ?string, productId: ?string, error: ?StoreException}
     */
    public function interpretApple(int $status, array $tx, ?array $renewal): array
    {
        $now = CarbonImmutable::now();
        $ms = fn ($v) => is_numeric($v) ? CarbonImmutable::createFromTimestampMs((int) $v, 'UTC') : null;
        $expiresAt = $ms($tx['expiresDate'] ?? null);
        $revoked = $status === 5 || isset($tx['revocationDate']);

        $premium = false;
        $error = null;
        $state = match (true) {
            $revoked => 'APPLE_REVOKED',
            $status === 1 => 'APPLE_ACTIVE',
            $status === 2 => 'APPLE_EXPIRED',
            $status === 3 => 'APPLE_BILLING_RETRY',
            $status === 4 => 'APPLE_GRACE_PERIOD',
            default => 'APPLE_UNKNOWN_'.$status,
        };

        if ($revoked) {
            $error = StoreException::invalid('Apple reembolsó o anuló esta compra.');
        } elseif ($status === 1 || $status === 4) {
            if ($status === 4) {
                // En gracia Apple sigue intentando cobrar y la persona conserva el acceso hasta gracePeriodExpiresDate.
                $grace = $ms($renewal['gracePeriodExpiresDate'] ?? null);
                $expiresAt = $grace ?? (($expiresAt === null || $expiresAt->lessThan($now->addDay())) ? $now->addDay() : $expiresAt);
            }
            $premium = $expiresAt !== null && $expiresAt->greaterThan($now);
            if (! $premium) {
                $error = StoreException::expired('La suscripción ya terminó.');
            }
        } elseif ($status === 2 || $status === 3) {
            $error = StoreException::expired($status === 3
                ? 'Apple no pudo cobrar la renovación de la suscripción.'
                : 'La suscripción ya terminó.');
        } else {
            $error = StoreException::invalid('La App Store no da esta compra por válida.');
        }

        $trial = ($tx['offerDiscountType'] ?? null) === 'FREE_TRIAL'
            || ((int) ($tx['offerType'] ?? 0) === 1 && ! isset($tx['offerDiscountType']) && isset($tx['price']) && (int) $tx['price'] === 0);
        $productId = isset($tx['productId']) ? (string) $tx['productId'] : null;

        return [
            'state' => $state,
            'premium' => $premium,
            'trial' => $premium && $trial,
            'autoRenewing' => $premium && (int) ($renewal['autoRenewStatus'] ?? 0) === 1,
            'expiresAt' => $expiresAt,
            'basePlan' => $productId !== null ? ($this->appleProducts()[$productId] ?? null) : null,
            'productId' => $productId,
            'error' => $error,
        ];
    }

    /**
     * Productos de la App Store que dan premium: APPLE_PRODUCT_IDS más los productos «ios» activos del panel.
     *
     * @return array<string, ?string> productId → plan (anual, mensual…)
     */
    public function appleProducts(): array
    {
        $map = [];
        foreach (array_filter(array_map('trim', explode(',', (string) config('mininoches.apple.products')))) as $item) {
            [$id, $plan] = array_pad(array_map('trim', explode(':', $item, 2)), 2, null);
            $map[$id] = $plan ?: null;
        }
        Product::query()->where('platform', 'ios')->where('active', true)->get(['product_id', 'base_plan'])
            ->each(function (Product $p) use (&$map) {
                $map[$p->product_id] ??= $p->base_plan ?: null;
            });

        return $map;
    }

    /** @return array{status: int, transaction: array, renewalInfo: ?array, environment: string} */
    private function latestAppleStatus(string $originalTransactionId, ?string $environment): array
    {
        $statuses = $this->apple->getSubscriptionStatuses($originalTransactionId, $environment);
        if (($statuses['bundleId'] ?? $this->apple->bundleId()) !== $this->apple->bundleId()) {
            throw StoreException::invalid('La compra es de otra app.');
        }
        foreach ($statuses['groups'] as $group) {
            foreach ($group['lastTransactions'] as $item) {
                $tx = $item['transaction'];
                if ((string) ($tx['originalTransactionId'] ?? $item['originalTransactionId']) !== $originalTransactionId) {
                    continue;
                }
                $this->assertAppleTransaction($tx);
                if (! array_key_exists((string) ($tx['productId'] ?? ''), $this->appleProducts())) {
                    throw StoreException::invalid('La suscripción actual no es un producto de esta app.');
                }
                if ($item['renewalInfo'] !== null
                    && (string) ($item['renewalInfo']['originalTransactionId'] ?? $originalTransactionId) !== $originalTransactionId) {
                    throw StoreException::invalid('La información de renovación no corresponde a esta compra.');
                }

                return $item + ['environment' => $statuses['environment']];
            }
        }

        throw StoreException::invalid('La App Store no da el estado de esta suscripción.');
    }

    private function assertAppleTransaction(array $tx): void
    {
        if (($tx['bundleId'] ?? null) !== $this->apple->bundleId()) {
            throw StoreException::invalid('La compra es de otra app.');
        }
        if (isset($tx['type']) && $tx['type'] !== 'Auto-Renewable Subscription') {
            throw StoreException::invalid('La compra no es una suscripción.');
        }
    }

    /** Estado deducido del tipo de notificación (por si una notificación antigua no trae `data.status`). */
    private function statusFromNotification(string $type, string $subtype, array $tx): int
    {
        return match (true) {
            in_array($type, ['REFUND', 'REVOKE'], true), isset($tx['revocationDate']) => 5,
            in_array($type, ['EXPIRED', 'GRACE_PERIOD_EXPIRED'], true) => 2,
            $type === 'DID_FAIL_TO_RENEW' => $subtype === 'GRACE_PERIOD' ? 4 : 3,
            default => (int) ($tx['expiresDate'] ?? 0) > CarbonImmutable::now()->getTimestampMs() ? 1 : 2,
        };
    }

    private function applyApple(Purchase $purchase, array $info, array $tx, ?array $renewal, string $source, ?int $signedDate = null): void
    {
        $purchase->fill([
            'product_id' => $info['productId'] ?? $purchase->product_id,
            'state' => $info['state'],
            'premium' => $info['premium'],
            'trial' => $info['trial'],
            'auto_renewing' => $info['autoRenewing'],
            'test_purchase' => ($tx['environment'] ?? 'Production') !== 'Production',
            'base_plan' => $info['basePlan'],
            'expires_at' => $info['expiresAt'],
            'raw_response' => [
                'source' => $source,
                'environment' => $tx['environment'] ?? null,
                'signedDate' => $signedDate ?? (int) ($tx['signedDate'] ?? CarbonImmutable::now()->getTimestampMs()),
                'transaction' => self::redactApple($tx),
                'renewalInfo' => $renewal !== null ? self::redactApple($renewal) : null,
            ],
            'last_verified_at' => now(),
        ])->save();
    }

    /** Los id de transacción de Apple no se guardan en claro (con ellos se podría reclamar la compra). */
    private static function redactApple(array $data): array
    {
        foreach (['originalTransactionId', 'transactionId', 'webOrderLineItemId', 'appAccountToken'] as $k) {
            if (isset($data[$k])) {
                $data[$k] = $k === 'originalTransactionId' ? '[sha256 en token_hash]' : 'sha256:'.hash('sha256', (string) $data[$k]);
            }
        }

        return $data;
    }

    /**
     * Traduce la respuesta de subscriptionsv2 al derecho.
     *
     * @return array{lineItem: ?array, state: string, premium: bool, trial: bool, autoRenewing: bool, expiresAt: ?CarbonImmutable, basePlan: ?string, error: ?StoreException}
     */
    public function interpretGoogle(array $response, string $productId): array
    {
        $now = CarbonImmutable::now();
        $state = (string) ($response['subscriptionState'] ?? 'SUBSCRIPTION_STATE_UNSPECIFIED');

        $lineItem = null;
        foreach ($response['lineItems'] ?? [] as $item) {
            if (($item['productId'] ?? null) !== $productId) {
                continue;
            }
            if ($lineItem === null || strcmp((string) ($item['expiryTime'] ?? ''), (string) ($lineItem['expiryTime'] ?? '')) > 0) {
                $lineItem = $item;
            }
        }

        $expiresAt = isset($lineItem['expiryTime']) ? CarbonImmutable::parse($lineItem['expiryTime'])->utc() : null;
        $offer = $lineItem['offerDetails'] ?? [];
        $trial = isset($lineItem['offerPhase']['freeTrial'])
            || str_contains(strtolower((string) ($offer['offerId'] ?? '')), 'trial')
            || collect($offer['offerTags'] ?? [])->contains(fn ($t) => str_contains(strtolower((string) $t), 'trial'));

        $premium = false;
        $error = null;
        if (in_array($state, self::PREMIUM_STATES, true)) {
            if ($state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' && ($expiresAt === null || $expiresAt->lessThan($now->addDay()))) {
                // En gracia Google sigue intentando cobrar: se da un día más y la app vuelve a preguntar.
                $expiresAt = $now->addDay();
            }
            $premium = $expiresAt !== null && $expiresAt->greaterThan($now);
            if (! $premium) {
                $error = StoreException::expired('La suscripción ya terminó.');
            }
        } elseif (in_array($state, self::EXPIRED_STATES, true)) {
            $error = StoreException::expired(match ($state) {
                'SUBSCRIPTION_STATE_ON_HOLD' => 'La suscripción está en espera: Google no pudo cobrar.',
                'SUBSCRIPTION_STATE_PAUSED' => 'La suscripción está en pausa.',
                default => 'La suscripción ya terminó.',
            });
        } elseif ($state === 'SUBSCRIPTION_STATE_PENDING') {
            $error = StoreException::invalid('El pago aún está pendiente en Google Play.');
        } else {
            $error = StoreException::invalid('Google Play no da esta compra por válida.');
        }

        return [
            'lineItem' => $lineItem,
            'state' => $state,
            'premium' => $premium,
            'trial' => $premium && $trial,
            'autoRenewing' => (bool) ($lineItem['autoRenewingPlan']['autoRenewEnabled'] ?? false),
            'expiresAt' => $expiresAt,
            'basePlan' => $offer['basePlanId'] ?? null,
            'error' => $error,
        ];
    }

    private function applyGoogle(Purchase $purchase, array $response, array $info): void
    {
        $purchase->fill([
            'state' => $info['state'],
            'premium' => $info['premium'],
            'trial' => $info['trial'],
            'auto_renewing' => $info['autoRenewing'],
            'test_purchase' => isset($response['testPurchase']),
            'base_plan' => $info['basePlan'],
            'expires_at' => $info['expiresAt'],
            'raw_response' => $response,
            'last_verified_at' => now(),
        ])->save();
    }

    private function applyPurchaseToEntitlement(Entitlement $entitlement, Purchase $purchase): void
    {
        $entitlement->fill([
            'purchase_id' => $purchase->id,
            'store_source' => $purchase->platform === 'ios' ? 'apple' : 'google',
            'store_product_id' => $purchase->product_id,
            'store_premium' => $purchase->premium,
            'store_trial' => $purchase->trial,
            'store_auto_renewing' => $purchase->auto_renewing,
            'store_expires_at' => $purchase->expires_at,
        ])->save();
    }

    private function syncEntitlements(Purchase $purchase): void
    {
        Entitlement::query()->where('purchase_id', $purchase->id)->get()
            ->each(fn (Entitlement $e) => $this->applyPurchaseToEntitlement($e, $purchase));
    }
}
