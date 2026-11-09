<?php

namespace App\Services;

use App\Exceptions\StoreException;
use App\Models\Entitlement;
use App\Models\Purchase;
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

    public function __construct(private readonly GooglePlayClient $google) {}

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

    /** iOS: aún no se verifica (App Store Server API). Se guarda la petición para procesarla después. */
    public function recordIos(string $installId, string $productId, ?string $transactionId): Purchase
    {
        // TODO(iOS): verificar con la App Store Server API (GET /inApps/v1/transactions/{transactionId}, JWT ES256 con la
        // clave de App Store Connect), decodificar el JWS firmado y llenar estado y fecha de fin como en Android.
        return Purchase::query()->updateOrCreate(
            ['platform' => 'ios', 'token_hash' => $transactionId ? Purchase::hashToken($transactionId) : null],
            [
                'install_id' => $installId,
                'product_id' => $productId,
                'transaction_id' => $transactionId,
                'state' => 'PENDING_VERIFICATION',
                'premium' => false,
            ]
        );
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
