<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\Purchase;
use App\Models\StoreNotification;
use App\Models\User;
use App\Services\Apple\AppleJwsException;
use App\Services\Apple\AppleJwsVerifier;
use App\Services\Apple\AppStoreClient;
use App\Services\Apple\Es256;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\AppleTestChain;
use Tests\TestCase;

/**
 * Verificación de compras de iOS (App Store Server API) y App Store Server Notifications v2, con una cadena de
 * certificados de prueba de verdad (raíz → intermedio → hoja con los OID de Apple): la verificación JWS se ejecuta.
 * Apple se simula con Http::fake; no se hace ninguna llamada real.
 */
class AppleVerifyTest extends TestCase
{
    private const BUNDLE = 'com.calderodecuentos.cuentos';

    private const PROD = 'https://api.storekit.itunes.apple.com/inApps/v1/';

    private const SANDBOX = 'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/';

    private const TX = '2000000111111111';

    private const ORIGINAL = '2000000100000000';

    private AppleTestChain $chain;

    private string $apiPublicPem;

    protected function setUp(): void
    {
        parent::setUp();
        $this->chain = AppleTestChain::make();
        $this->trustRoot($this->chain);
    }

    private function trustRoot(AppleTestChain $chain): void
    {
        config([
            'mininoches.apple.root_certificates' => [$chain->rootPem],
            'mininoches.apple.root_fingerprints' => [$chain->fingerprint()],
        ]);
        $this->app->forgetInstance(AppleJwsVerifier::class);
        $this->app->forgetInstance(AppStoreClient::class);
    }

    private function configureApple(array $extra = []): void
    {
        $key = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
        openssl_pkey_export($key, $pem);
        $this->apiPublicPem = openssl_pkey_get_details($key)['key'];
        config(['mininoches.apple' => array_replace(config('mininoches.apple'), [
            'issuer_id' => '57246542-96fe-1a63-e053-0824d011072a',
            'key_id' => '2X9R4HXF34',
            'private_key' => $pem,
            'bundle_id' => self::BUNDLE,
            'environment' => 'production',
        ], $extra)]);
        $this->app->forgetInstance(AppStoreClient::class);
    }

    private function ms(\DateTimeInterface $d): int
    {
        return (int) $d->format('Uv');
    }

    private function tx(array $extra = []): array
    {
        return array_replace([
            'transactionId' => self::TX,
            'originalTransactionId' => self::ORIGINAL,
            'webOrderLineItemId' => '2000000033333333',
            'bundleId' => self::BUNDLE,
            'productId' => 'mininoches_premium_anual',
            'subscriptionGroupIdentifier' => '21000000',
            'purchaseDate' => $this->ms(now()->subDay()),
            'originalPurchaseDate' => $this->ms(now()->subMonth()),
            'expiresDate' => $this->ms(now()->addYear()->startOfSecond()),
            'quantity' => 1,
            'type' => 'Auto-Renewable Subscription',
            'inAppOwnershipType' => 'PURCHASED',
            'signedDate' => $this->ms(now()),
            'environment' => 'Production',
            'transactionReason' => 'PURCHASE',
            'storefront' => 'PAN',
            'price' => 29990,
            'currency' => 'USD',
        ], $extra);
    }

    private function renewal(array $extra = []): array
    {
        return array_replace([
            'originalTransactionId' => self::ORIGINAL,
            'autoRenewProductId' => 'mininoches_premium_anual',
            'productId' => 'mininoches_premium_anual',
            'autoRenewStatus' => 1,
            'signedDate' => $this->ms(now()),
            'environment' => 'Production',
        ], $extra);
    }

    /** @var array<string, mixed>|null lo que responderá la App Store simulada */
    private ?array $apple = null;

    private bool $faked = false;

    /**
     * Apple simulado. $tx y $renewal son los contenidos que la «App Store» firma con la cadena (o con $signer).
     *
     * @param  string  $env  production | sandbox: dónde existe la transacción (en el otro, 404)
     */
    private function fakeApple(array $tx, int $status = 1, ?array $renewal = null, string $env = 'production', ?\Closure $signer = null): void
    {
        $this->apple = [
            'tx' => $tx, 'status' => $status, 'env' => $env,
            'renewal' => $renewal ?? $this->renewal(['environment' => $tx['environment']]),
            'sign' => $signer ?? fn (array $p) => $this->chain->sign($p),
        ];
        $this->registerFake();
    }

    private function fakeAppleError(int $status, array|string $body = ''): void
    {
        $this->apple = ['error' => [$status, $body]];
        $this->registerFake();
    }

    private function registerFake(): void
    {
        if ($this->faked) {
            return;
        }
        $this->faked = true;
        Http::fake(fn (Request $r) => $this->respond($r));
    }

    private function respond(Request $r)
    {
        $s = $this->apple;
        if (isset($s['error'])) {
            return Http::response($s['error'][1], $s['error'][0]);
        }
        $env = str_starts_with($r->url(), self::PROD) ? 'production' : 'sandbox';
        if ($env !== $s['env']) {
            return Http::response(['errorCode' => 4040010, 'errorMessage' => 'Transaction id not found.'], 404);
        }
        $tx = $s['tx'];
        if (str_contains($r->url(), '/inApps/v1/transactions/')) {
            return Http::response(['signedTransactionInfo' => ($s['sign'])($tx)]);
        }

        return Http::response([
            'environment' => $tx['environment'],
            'bundleId' => $tx['bundleId'],
            'appAppleId' => 1234567890,
            'data' => [[
                'subscriptionGroupIdentifier' => '21000000',
                'lastTransactions' => [[
                    'status' => $s['status'],
                    'originalTransactionId' => $tx['originalTransactionId'],
                    'signedTransactionInfo' => ($s['sign'])($tx),
                    'signedRenewalInfo' => ($s['sign'])($s['renewal']),
                ]],
            ]],
        ]);
    }

    private function verify(string $installId, string $productId = 'mininoches_premium_anual', string $transactionId = self::TX): TestResponse
    {
        return $this->postJson('/v1/purchases/verify', [
            'installId' => $installId, 'platform' => 'ios', 'productId' => $productId, 'transactionId' => $transactionId,
        ]);
    }

    private function notification(string $type, array $tx, ?array $renewal = null, array $extra = [], ?int $status = null): array
    {
        $data = [
            'appAppleId' => 1234567890,
            'bundleId' => self::BUNDLE,
            'bundleVersion' => '1',
            'environment' => 'Production',
            'signedTransactionInfo' => $this->chain->sign($tx),
            'signedRenewalInfo' => $this->chain->sign($renewal ?? $this->renewal()),
        ];
        if ($status !== null) {
            $data['status'] = $status;
        }

        return array_replace_recursive([
            'notificationType' => $type,
            'notificationUUID' => (string) Str::uuid(),
            'version' => '2.0',
            'signedDate' => $this->ms(now()),
            'data' => $data,
        ], $extra);
    }

    private function postNotification(array $payload, ?AppleTestChain $chain = null): TestResponse
    {
        return $this->postJson('/v1/webhooks/apple', ['signedPayload' => ($chain ?? $this->chain)->sign($payload)]);
    }

    // ── Verificación ──────────────────────────────────────────────────────────────────────────────────────────

    public function test_active_subscription_gives_signed_premium_entitlement(): void
    {
        $this->configureApple();
        $tx = $this->tx();
        $this->fakeApple($tx);
        $id = $this->installId();

        $res = $this->verify($id)->assertOk()->assertJson([
            'installId' => $id, 'premium' => true, 'source' => 'apple', 'productId' => 'mininoches_premium_anual',
            'trial' => false, 'autoRenewing' => true,
            'expiresAt' => gmdate('Y-m-d\TH:i:s\Z', intdiv($tx['expiresDate'], 1000)),
        ]);
        $this->assertSignatureValid($res->json());

        $purchase = Purchase::query()->sole();
        $this->assertSame('ios', $purchase->platform);
        $this->assertSame(hash('sha256', self::ORIGINAL), $purchase->token_hash);
        $this->assertSame(self::ORIGINAL, $purchase->token());
        $this->assertNull($purchase->transaction_id);
        $this->assertSame('APPLE_ACTIVE', $purchase->state);
        $this->assertSame('anual', $purchase->base_plan);
        $this->assertFalse($purchase->test_purchase);
        // Ni el id de la transacción ni el original quedan en claro en la base de datos.
        $row = json_encode(\DB::table('purchases')->first());
        $this->assertStringNotContainsString(self::ORIGINAL, $row);
        $this->assertStringNotContainsString(self::TX, $row);

        // JWT ES256 con la clave de App Store Connect: cabecera, claims y firma R||S verificables con la pública.
        Http::assertSent(function (Request $r) {
            if (! str_starts_with($r->url(), self::PROD.'transactions/'.self::TX)) {
                return false;
            }
            [$h, $c, $s] = explode('.', substr($r->header('Authorization')[0], 7));
            $header = json_decode(Es256::b64urlDecode($h), true);
            $claims = json_decode(Es256::b64urlDecode($c), true);

            return $header === ['alg' => 'ES256', 'kid' => '2X9R4HXF34', 'typ' => 'JWT']
                && $claims['aud'] === 'appstoreconnect-v1' && $claims['bid'] === self::BUNDLE
                && $claims['iss'] === '57246542-96fe-1a63-e053-0824d011072a'
                && $claims['exp'] - $claims['iat'] <= 3600
                && openssl_verify("{$h}.{$c}", Es256::rawToDer(Es256::b64urlDecode($s)), $this->apiPublicPem, OPENSSL_ALGO_SHA256) === 1;
        });
        Http::assertSent(fn (Request $r) => $r->url() === self::PROD.'subscriptions/'.self::ORIGINAL);
        Http::assertNotSent(fn (Request $r) => str_starts_with($r->url(), self::SANDBOX));

        $this->getJson('/v1/entitlements?installId='.$id)->assertOk()->assertJson(['premium' => true, 'source' => 'apple']);
    }

    public function test_free_trial_is_premium_and_flagged(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx([
            'offerType' => 1, 'offerDiscountType' => 'FREE_TRIAL', 'price' => 0,
            'expiresDate' => $this->ms(now()->addDays(7)),
        ]));

        $res = $this->verify($this->installId())->assertOk()->assertJson(['premium' => true, 'trial' => true]);
        $this->assertSignatureValid($res->json());
        $this->assertTrue(Purchase::query()->sole()->trial);
    }

    public function test_billing_grace_period_is_premium_until_grace_ends(): void
    {
        $this->configureApple();
        $grace = now()->addDays(6)->startOfSecond();
        $this->fakeApple($this->tx(['expiresDate' => $this->ms(now()->subDay())]), 4,
            $this->renewal(['gracePeriodExpiresDate' => $this->ms($grace), 'isInBillingRetryPeriod' => true]));

        $this->verify($this->installId())->assertOk()
            ->assertJson(['premium' => true, 'expiresAt' => $grace->utc()->format('Y-m-d\TH:i:s\Z')]);
        $this->assertSame('APPLE_GRACE_PERIOD', Purchase::query()->sole()->state);
    }

    public function test_cancelled_renewal_is_premium_until_expiry_without_auto_renew(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx(), 1, $this->renewal(['autoRenewStatus' => 0, 'expirationIntent' => 1]));

        $this->verify($this->installId())->assertOk()->assertJson(['premium' => true, 'autoRenewing' => false]);
    }

    public function test_expired_and_billing_retry_return_402_expired(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx(['expiresDate' => $this->ms(now()->subDay())]), 2);
        $id = $this->installId();

        $this->verify($id)->assertStatus(402)->assertJson(['error' => 'expired']);
        $this->assertFalse(Purchase::query()->sole()->premium);
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => false, 'source' => 'none']);

        $this->fakeApple($this->tx(['expiresDate' => $this->ms(now()->subDay())]), 3);
        $this->verify($id)->assertStatus(402)->assertJson(['error' => 'expired']);
        $this->assertSame('APPLE_BILLING_RETRY', Purchase::query()->sole()->state);
    }

    public function test_refunded_purchase_is_not_premium(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx(['revocationDate' => $this->ms(now()->subHour()), 'revocationReason' => 0]), 5);
        $id = $this->installId();

        $this->verify($id)->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
        $this->assertSame('APPLE_REVOKED', Purchase::query()->sole()->state);
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => false]);
    }

    public function test_other_bundle_is_rejected_and_not_stored(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx(['bundleId' => 'com.otra.app']));

        $this->verify($this->installId())->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
        $this->assertSame(0, Purchase::query()->count());
    }

    public function test_other_or_unknown_product_is_rejected(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx(['productId' => 'mininoches_premium_mensual']));
        // La transacción es del mensual pero la app dice anual.
        $this->verify($this->installId())->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
        // Un producto que no da premium ni siquiera se consulta.
        $sent = Http::recorded()->count();
        $this->verify($this->installId(), 'monedas_100')->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
        $this->assertSame($sent, Http::recorded()->count());
        $this->assertSame(0, Purchase::query()->count());
    }

    public function test_ios_products_from_the_panel_are_accepted(): void
    {
        $this->configureApple(['products' => '']);
        Product::query()->create(['product_id' => 'mininoches_premium', 'platform' => 'ios', 'base_plan' => 'anual', 'period' => 'P1Y', 'trial_days' => 7]);
        $this->fakeApple($this->tx(['productId' => 'mininoches_premium']));

        $this->verify($this->installId(), 'mininoches_premium')->assertOk()->assertJson(['premium' => true, 'productId' => 'mininoches_premium']);
    }

    public function test_bad_signatures_are_rejected(): void
    {
        $this->configureApple();
        $id = $this->installId();

        // Contenido alterado después de firmar.
        $this->fakeApple($this->tx(), 1, null, 'production', function (array $p) {
            [$h, , $s] = explode('.', $this->chain->sign($p));

            return $h.'.'.Es256::b64url(json_encode(['expiresDate' => $this->ms(now()->addYears(50))] + $p)).'.'.$s;
        });
        $this->verify($id)->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);

        // Cadena de otra raíz (no la de confianza).
        $other = AppleTestChain::make(name: 'ajena');
        $this->fakeApple($this->tx(), 1, null, 'production', fn (array $p) => $other->sign($p));
        $this->verify($id)->assertStatus(402);

        // Cadena ajena que presenta la raíz de confianza al final (el intermedio no está firmado por ella).
        $this->fakeApple($this->tx(), 1, null, 'production', fn (array $p) => $other->sign($p, $this->chain->rootPem));
        $this->verify($id)->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
        // Hoja ajena con el intermedio y la raíz de confianza (la hoja no está firmada por ese intermedio).
        $this->fakeApple($this->tx(), 1, null, 'production', fn (array $p) => $other->sign($p, $this->chain->rootPem, $this->chain->intermediatePem));
        $this->verify($id)->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);

        // Hoja sin el OID de App Store (aunque esté firmada por la raíz de confianza) e intermedio sin su OID.
        foreach ([AppleTestChain::make(leafOid: false, name: 'principal-sin-oid'), AppleTestChain::make(intermediateOid: false, name: 'principal-sin-oid')] as $bad) {
            $this->trustRoot($bad);
            $this->configureApple();
            $this->fakeApple($this->tx(), 1, null, 'production', fn (array $p) => $bad->sign($p));
            $this->verify($id)->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
        }

        // Sin firma.
        $this->trustRoot($this->chain);
        $this->configureApple();
        $this->fakeApple($this->tx(), 1, null, 'production', fn (array $p) => Es256::b64url('{"alg":"none"}').'.'.Es256::b64url(json_encode($p)).'.');
        $this->verify($id)->assertStatus(402);

        $this->assertSame(0, Purchase::query()->count());
    }

    public function test_sandbox_fallback_when_production_does_not_know_the_transaction(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx(['environment' => 'Sandbox']), 1, null, 'sandbox');

        $this->verify($this->installId())->assertOk()->assertJson(['premium' => true, 'source' => 'apple']);
        $this->assertTrue(Purchase::query()->sole()->test_purchase);
        Http::assertSent(fn (Request $r) => $r->url() === self::PROD.'transactions/'.self::TX);
        Http::assertSent(fn (Request $r) => $r->url() === self::SANDBOX.'transactions/'.self::TX);
        // El estado se pide directamente en el entorno donde apareció la transacción.
        Http::assertSent(fn (Request $r) => $r->url() === self::SANDBOX.'subscriptions/'.self::ORIGINAL);
        Http::assertNotSent(fn (Request $r) => $r->url() === self::PROD.'subscriptions/'.self::ORIGINAL);
    }

    public function test_sandbox_environment_and_no_fallback(): void
    {
        $this->configureApple(['environment' => 'sandbox']);
        $this->fakeApple($this->tx(['environment' => 'Sandbox']), 1, null, 'sandbox');
        $this->verify($this->installId())->assertOk();
        Http::assertNotSent(fn (Request $r) => str_starts_with($r->url(), self::PROD));

        $this->configureApple(['sandbox_fallback' => false]);
        $this->verify($this->installId())->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
    }

    public function test_unknown_transaction_is_invalid(): void
    {
        $this->configureApple();
        $this->fakeAppleError(404, ['errorCode' => 4040010]);
        $this->verify($this->installId())->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
        $this->verify($this->installId(), transactionId: '../../apps')->assertStatus(402);
    }

    public function test_not_configured_returns_503(): void
    {
        Http::fake();
        $this->verify($this->installId())->assertStatus(503)->assertJson(['error' => 'store_unavailable']);
        Http::assertNothingSent();
        $this->assertSame(0, Purchase::query()->count());
    }

    public function test_apple_down_or_rejecting_the_key_returns_503(): void
    {
        $this->configureApple();
        $this->fakeAppleError(500, ['errorCode' => 5000000]);
        $this->verify($this->installId())->assertStatus(503)->assertJson(['error' => 'store_unavailable']);

        $this->configureApple();
        $this->fakeAppleError(401);
        $this->verify($this->installId())->assertStatus(503)->assertJson(['error' => 'store_unavailable']);
    }

    public function test_expired_entitlement_is_refreshed_from_apple(): void
    {
        $this->configureApple();
        $this->fakeApple($this->tx(['expiresDate' => $this->ms(now()->addHour())]));
        $id = $this->installId();
        $this->verify($id)->assertOk();

        // Se perdió la notificación de renovación: al pedir el derecho caducado, el servidor vuelve a preguntar.
        $this->travel(2)->hours();
        $this->fakeApple($this->tx(['expiresDate' => $this->ms(now()->addMonth())]));
        $this->getJson('/v1/entitlements?installId='.$id)->assertOk()->assertJson(['premium' => true, 'source' => 'apple']);
        Http::assertSent(fn (Request $r) => $r->url() === self::PROD.'subscriptions/'.self::ORIGINAL);
    }

    // ── Notificaciones v2 ────────────────────────────────────────────────────────────────────────────────────

    private function subscribed(): string
    {
        $this->configureApple();
        $this->fakeApple($this->tx(['expiresDate' => $this->ms(now()->addMonth())]));
        $id = $this->installId();
        $this->verify($id)->assertOk();

        return $id;
    }

    public function test_did_renew_extends_the_entitlement(): void
    {
        $id = $this->subscribed();
        $newExpiry = now()->addYear()->addMonth()->startOfSecond();
        $sent = Http::recorded()->count(); // las notificaciones no vuelven a llamar a Apple

        $n = $this->notification('DID_RENEW', $this->tx(['transactionId' => '2000000222222222', 'expiresDate' => $this->ms($newExpiry)]), status: 1);
        $this->postNotification($n)->assertOk();

        $this->getJson('/v1/entitlements?installId='.$id)
            ->assertJson(['premium' => true, 'expiresAt' => $newExpiry->utc()->format('Y-m-d\TH:i:s\Z')]);
        $stored = StoreNotification::query()->sole();
        $this->assertSame('DID_RENEW', $stored->type);
        $this->assertSame('applied:APPLE_ACTIVE', $stored->result);
        $this->assertSame($n['notificationUUID'], $stored->notification_id);
        $this->assertSame(hash('sha256', self::ORIGINAL), $stored->token_hash);
        $this->assertStringNotContainsString(self::ORIGINAL, json_encode($stored->payload));
        $this->assertSame($sent, Http::recorded()->count());
    }

    public function test_refund_removes_premium_and_duplicate_uuid_is_ignored(): void
    {
        $id = $this->subscribed();
        $n = $this->notification('REFUND', $this->tx(['revocationDate' => $this->ms(now()), 'revocationReason' => 0]), status: 5);

        $this->postNotification($n)->assertOk();
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => false, 'source' => 'none']);
        $this->assertSame('APPLE_REVOKED', Purchase::query()->sole()->state);

        // Apple reintenta la misma notificación: 200 y no se vuelve a procesar ni a guardar.
        $before = Purchase::query()->sole()->updated_at;
        $this->travel(1)->minutes();
        $this->postNotification($n)->assertOk();
        $this->assertSame(1, StoreNotification::query()->count());
        $this->assertEquals($before, Purchase::query()->sole()->updated_at);
    }

    public function test_grace_period_then_expired(): void
    {
        $id = $this->subscribed();
        $grace = now()->addDays(16)->startOfSecond();
        $this->postNotification($this->notification('DID_FAIL_TO_RENEW', $this->tx(['expiresDate' => $this->ms(now()->subMinute())]),
            $this->renewal(['gracePeriodExpiresDate' => $this->ms($grace)]), ['subtype' => 'GRACE_PERIOD']))->assertOk();
        $this->getJson('/v1/entitlements?installId='.$id)
            ->assertJson(['premium' => true, 'expiresAt' => $grace->utc()->format('Y-m-d\TH:i:s\Z')]);

        $this->travel(1)->minutes();
        $this->postNotification($this->notification('GRACE_PERIOD_EXPIRED', $this->tx(['expiresDate' => $this->ms(now()->subDay())])))->assertOk();
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => false]);
        $this->assertSame('APPLE_EXPIRED', Purchase::query()->sole()->state);
    }

    public function test_auto_renew_turned_off_keeps_premium_until_expiry(): void
    {
        $id = $this->subscribed();
        $this->postNotification($this->notification('DID_CHANGE_RENEWAL_STATUS', $this->tx(['expiresDate' => $this->ms(now()->addMonth())]),
            $this->renewal(['autoRenewStatus' => 0]), ['subtype' => 'AUTO_RENEW_DISABLED'], 1))->assertOk();
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => true, 'autoRenewing' => false]);
    }

    public function test_bad_signature_notification_is_400_and_not_stored(): void
    {
        $this->subscribed();
        $n = $this->notification('REFUND', $this->tx(['revocationDate' => $this->ms(now())]), status: 5);

        // signedPayload alterado
        [$h, , $s] = explode('.', $this->chain->sign($n));
        $this->postJson('/v1/webhooks/apple', ['signedPayload' => $h.'.'.Es256::b64url(json_encode($n + ['x' => 1])).'.'.$s])->assertStatus(400);
        // firmado con otra cadena
        $this->postNotification($n, AppleTestChain::make(name: 'ajena'))->assertStatus(400);
        // sin firmar o sin signedPayload
        $this->postJson('/v1/webhooks/apple', ['signedPayload' => 'eyJ...'])->assertStatus(400);
        $this->postJson('/v1/webhooks/apple', [])->assertStatus(400);
        // el payload exterior es bueno pero la transacción de dentro está firmada por otra cadena
        $n['data']['signedTransactionInfo'] = AppleTestChain::make(name: 'ajena')->sign($this->tx(['revocationDate' => $this->ms(now())]));
        $this->postNotification($n)->assertStatus(400);

        $this->assertSame(0, StoreNotification::query()->count());
        $this->assertTrue(Purchase::query()->sole()->premium);
    }

    public function test_notifications_for_unknown_purchases_other_bundles_and_stale_ones(): void
    {
        // Sin clave de API también se reciben y verifican (solo hace falta la raíz y el bundle id).
        $this->postNotification($this->notification('SUBSCRIBED', $this->tx(), extra: ['subtype' => 'INITIAL_BUY']))->assertOk();
        $this->assertSame('unknown_purchase', StoreNotification::query()->latest('id')->first()->result);

        $this->postNotification($this->notification('DID_RENEW', $this->tx(), extra: ['data' => ['bundleId' => 'com.otra.app']]))->assertOk();
        $this->assertSame('other_bundle', StoreNotification::query()->latest('id')->first()->result);

        $this->postNotification($this->notification('TEST', $this->tx()))->assertOk();
        $this->assertSame('test', StoreNotification::query()->latest('id')->first()->result);

        $id = $this->subscribed();
        // Una notificación EXPIRED firmada antes de la última verificación llega tarde: no pisa el estado.
        $this->postNotification($this->notification('EXPIRED', $this->tx(['expiresDate' => $this->ms(now()->subDay())]),
            extra: ['signedDate' => $this->ms(now()->subHour())]))->assertOk();
        $this->assertSame('stale', StoreNotification::query()->latest('id')->first()->result);
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => true]);
    }

    public function test_admin_lists_and_shows_ios_purchases(): void
    {
        $this->subscribed();
        $this->artisan('mininoches:admin', ['email' => 'duena@mininoches.app', '--password' => 'una-clave-muy-larga'])->assertSuccessful();
        $admin = User::query()->sole();
        $purchase = Purchase::query()->sole();

        $this->actingAs($admin)->get('/admin/compras?tienda=ios')->assertOk()->assertSee('App Store')->assertSee('ACTIVE')
            ->assertSee(route('admin.purchases.show', $purchase), false);
        $this->actingAs($admin)->get('/admin/compras?q='.self::ORIGINAL)->assertOk()->assertSee($purchase->install_id);
        $this->actingAs($admin)->get('/admin/compras?tienda=android')->assertOk()->assertSee('Sin compras.');
        $this->actingAs($admin)->get('/admin/compras/'.$purchase->id)->assertOk()
            ->assertSee('Hash de la transacción original')->assertSee('mininoches_premium_anual')->assertDontSee(self::ORIGINAL);
        $this->actingAs($admin)->get('/admin')->assertOk()->assertSee('App Store (APPLE_ISSUER_ID');
    }

    // ── Verificador ──────────────────────────────────────────────────────────────────────────────────────────

    public function test_pinned_apple_root_is_the_published_g3_and_does_not_trust_the_test_chain(): void
    {
        $pem = file_get_contents(resource_path('certs/AppleRootCA-G3.pem'));
        $this->assertSame('63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179', openssl_x509_fingerprint($pem, 'sha256'));
        $this->assertSame('Apple Root CA - G3', openssl_x509_parse($pem)['subject']['CN']);

        $real = new AppleJwsVerifier([resource_path('certs/AppleRootCA-G3.pem')], ['63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79']);
        $this->expectException(AppleJwsException::class);
        $real->verify($this->chain->sign(['a' => 1]));
    }

    public function test_root_file_without_pinned_fingerprint_is_not_trusted(): void
    {
        $verifier = new AppleJwsVerifier([$this->chain->rootPem], ['00']);
        $this->expectException(AppleJwsException::class);
        $verifier->verify($this->chain->sign(['a' => 1]));
    }

    public function test_expired_certificates_are_rejected(): void
    {
        $verifier = app(AppleJwsVerifier::class);
        $this->assertSame(['a' => 1], $verifier->verify($this->chain->sign(['a' => 1])));

        $this->travel(11 * 365)->days(); // los certificados de prueba valen 10 años
        $this->expectException(AppleJwsException::class);
        $verifier->verify($this->chain->sign(['a' => 1]));
    }

    public function test_expired_leaf_is_rejected_even_if_root_and_intermediate_are_valid(): void
    {
        $shortLived = AppleTestChain::make(name: 'hoja-corta', leafDays: 1);
        $this->trustRoot($shortLived);
        $verifier = app(AppleJwsVerifier::class);
        $this->assertSame(['a' => 1], $verifier->verify($shortLived->sign(['a' => 1])));

        $this->travel(2)->days();
        $this->expectException(AppleJwsException::class);
        $verifier->verify($shortLived->sign(['a' => 1]));
    }

    public function test_es256_signature_conversion_round_trips(): void
    {
        $key = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
        for ($i = 0; $i < 20; $i++) {
            openssl_sign("mensaje {$i}", $der, $key, OPENSSL_ALGO_SHA256);
            $raw = Es256::derToRaw($der);
            $this->assertSame(64, strlen($raw));
            $this->assertSame(1, openssl_verify("mensaje {$i}", Es256::rawToDer($raw), openssl_pkey_get_details($key)['key'], OPENSSL_ALGO_SHA256));
        }
    }
}
