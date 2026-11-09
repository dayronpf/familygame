<?php

namespace Tests\Feature;

use App\Models\Entitlement;
use App\Models\Purchase;
use App\Models\StoreNotification;
use App\Services\GooglePlayClient;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class PurchaseVerifyTest extends TestCase
{
    private const SUBS = 'androidpublisher.googleapis.com/androidpublisher/v3/applications/com.calderodecuentos.cuentos/purchases/subscriptionsv2/tokens/*';

    private string $publicPem;

    protected function configureGoogle(): void
    {
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($key, $pem);
        $this->publicPem = openssl_pkey_get_details($key)['key'];
        config(['mininoches.google.service_account_json' => json_encode([
            'type' => 'service_account',
            'client_email' => 'verificador@mininoches.iam.gserviceaccount.com',
            'private_key' => $pem,
        ])]);
        $this->app->forgetInstance(GooglePlayClient::class);
    }

    /** @var array{0: array, 1: int} respuesta que dará el Google falso en la próxima consulta */
    private array $nextGoogle = [[], 200];

    private bool $faked = false;

    private function fakeGoogle(array $subscription, int $status = 200): void
    {
        $this->nextGoogle = [$subscription, $status];
        if ($this->faked) {
            return;
        }
        $this->faked = true;
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'ya29.prueba', 'expires_in' => 3599]),
            '*:acknowledge' => Http::response([], 200),
            self::SUBS => fn () => Http::response($this->nextGoogle[0], $this->nextGoogle[1]),
        ]);
    }

    private function subscription(string $state, string $expiry, array $extra = []): array
    {
        return array_replace_recursive([
            'kind' => 'androidpublisher#subscriptionPurchaseV2',
            'startTime' => now()->subDay()->toIso8601ZuluString(),
            'subscriptionState' => $state,
            'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
            'lineItems' => [[
                'productId' => 'mininoches_premium',
                'expiryTime' => $expiry,
                'autoRenewingPlan' => ['autoRenewEnabled' => true],
                'offerDetails' => ['basePlanId' => 'anual'],
            ]],
        ], $extra);
    }

    private function verify(string $installId, string $token = 'token-de-prueba'): TestResponse
    {
        return $this->postJson('/v1/purchases/verify', [
            'installId' => $installId, 'platform' => 'android', 'productId' => 'mininoches_premium', 'purchaseToken' => $token,
        ]);
    }

    public function test_active_subscription_gives_signed_premium_entitlement(): void
    {
        $this->configureGoogle();
        $expiry = now()->addYear()->startOfSecond();
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_ACTIVE', $expiry->toIso8601ZuluString()));
        $id = $this->installId();

        $res = $this->verify($id)->assertOk()->assertJson([
            'installId' => $id, 'premium' => true, 'source' => 'google', 'productId' => 'mininoches_premium',
            'trial' => false, 'autoRenewing' => true, 'expiresAt' => $expiry->utc()->format('Y-m-d\TH:i:s\Z'),
        ]);
        $this->assertSignatureValid($res->json());

        $purchase = Purchase::query()->sole();
        $this->assertSame(hash('sha256', 'token-de-prueba'), $purchase->token_hash);
        $this->assertSame('token-de-prueba', $purchase->token());
        $this->assertStringNotContainsString('token-de-prueba', $purchase->getRawOriginal('token_encrypted'));
        $this->assertSame('SUBSCRIPTION_STATE_ACTIVE', $purchase->raw_response['subscriptionState']);
        $this->assertSame('anual', $purchase->base_plan);

        // El JWT de la cuenta de servicio va firmado con RS256 y la clave privada configurada.
        Http::assertSent(function (Request $r) {
            if ($r->url() !== 'https://oauth2.googleapis.com/token') {
                return false;
            }
            [$h, $c, $s] = explode('.', $r['assertion']);
            $sig = base64_decode(strtr($s, '-_', '+/'));
            $claims = json_decode(base64_decode(strtr($c, '-_', '+/')), true);

            return openssl_verify("{$h}.{$c}", $sig, $this->publicPem, OPENSSL_ALGO_SHA256) === 1
                && $claims['scope'] === 'https://www.googleapis.com/auth/androidpublisher'
                && $r['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer';
        });
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'subscriptionsv2/tokens/token-de-prueba')
            && $r->hasHeader('Authorization', 'Bearer ya29.prueba'));

        // Y la instalación queda con su derecho.
        $this->getJson('/v1/entitlements?installId='.$id)->assertOk()->assertJson(['premium' => true, 'source' => 'google']);
    }

    public function test_free_trial_is_premium_and_flagged(): void
    {
        $this->configureGoogle();
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_ACTIVE', now()->addDays(7)->toIso8601ZuluString(), [
            'acknowledgementState' => 'ACKNOWLEDGEMENT_STATE_PENDING',
            'lineItems' => [['offerPhase' => ['freeTrial' => (object) []], 'offerDetails' => ['offerId' => 'prueba-7-dias']]],
        ]));

        $res = $this->verify($this->installId())->assertOk()->assertJson(['premium' => true, 'trial' => true]);
        $this->assertSignatureValid($res->json());
        Http::assertSent(fn (Request $r) => str_ends_with($r->url(), ':acknowledge'));
    }

    public function test_canceled_but_paid_until_future_is_still_premium(): void
    {
        $this->configureGoogle();
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_CANCELED', now()->addDays(3)->toIso8601ZuluString(), [
            'lineItems' => [['autoRenewingPlan' => ['autoRenewEnabled' => false]]],
        ]));

        $this->verify($this->installId())->assertOk()->assertJson(['premium' => true, 'autoRenewing' => false]);
    }

    public function test_expired_subscription_returns_402(): void
    {
        $this->configureGoogle();
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_EXPIRED', now()->subDay()->toIso8601ZuluString()));
        $id = $this->installId();

        $this->verify($id)->assertStatus(402)->assertJson(['error' => 'expired']);
        $this->assertFalse(Purchase::query()->sole()->premium);
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => false, 'source' => 'none']);
    }

    public function test_on_hold_and_unknown_token_return_402(): void
    {
        $this->configureGoogle();
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_ON_HOLD', now()->subDay()->toIso8601ZuluString()));
        $this->verify($this->installId())->assertStatus(402)->assertJson(['error' => 'expired']);

        $this->fakeGoogle(['error' => ['code' => 404]], 404);
        $this->verify($this->installId(), 'otro')->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
    }

    public function test_other_product_is_invalid(): void
    {
        $this->configureGoogle();
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_ACTIVE', now()->addYear()->toIso8601ZuluString(), [
            'lineItems' => [['productId' => 'otro_producto']],
        ]));
        $this->verify($this->installId())->assertStatus(402)->assertJson(['error' => 'invalid_purchase']);
    }

    public function test_google_not_configured_returns_503(): void
    {
        Http::fake();
        $this->verify($this->installId())->assertStatus(503)->assertJson(['error' => 'store_unavailable']);
        Http::assertNothingSent();
    }

    public function test_google_server_error_returns_503(): void
    {
        $this->configureGoogle();
        $this->fakeGoogle([], 500);
        $this->verify($this->installId())->assertStatus(503)->assertJson(['error' => 'store_unavailable']);
    }

    public function test_ios_is_stored_and_returns_503(): void
    {
        $id = $this->installId();
        $this->postJson('/v1/purchases/verify', [
            'installId' => $id, 'platform' => 'ios', 'productId' => 'mininoches_premium', 'transactionId' => '2000000123',
        ])->assertStatus(503)->assertJson(['error' => 'store_unavailable']);
        $this->assertSame('PENDING_VERIFICATION', Purchase::query()->sole()->state);
    }

    public function test_invalid_bodies_are_422(): void
    {
        $this->postJson('/v1/purchases/verify', ['installId' => 'no-es-uuid', 'platform' => 'android', 'productId' => 'x', 'purchaseToken' => 't'])
            ->assertStatus(422);
        $this->postJson('/v1/purchases/verify', ['installId' => $this->installId(), 'platform' => 'android', 'productId' => 'x'])
            ->assertStatus(422);
        $this->postJson('/v1/purchases/verify', [
            'installId' => $this->installId(), 'platform' => 'android', 'productId' => 'x', 'purchaseToken' => 't', 'childName' => 'Ana',
        ])->assertStatus(422);
    }

    public function test_webhook_requires_token_and_refreshes_purchase(): void
    {
        config(['mininoches.google.rtdn_token' => 'secreto-rtdn']);
        $this->configureGoogle();
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_ACTIVE', now()->addMonth()->toIso8601ZuluString()));
        $id = $this->installId();
        $this->verify($id)->assertOk();

        $body = ['message' => ['data' => base64_encode(json_encode([
            'version' => '1.0', 'packageName' => 'com.calderodecuentos.cuentos', 'eventTimeMillis' => '1',
            'subscriptionNotification' => ['version' => '1.0', 'notificationType' => 13, 'purchaseToken' => 'token-de-prueba', 'subscriptionId' => 'mininoches_premium'],
        ])), 'messageId' => '1'], 'subscription' => 'projects/x/subscriptions/y'];

        $this->postJson('/v1/webhooks/google', $body)->assertStatus(403);
        $this->postJson('/v1/webhooks/google?token=malo', $body)->assertStatus(403);

        // Google dice ahora que caducó.
        $this->fakeGoogle($this->subscription('SUBSCRIPTION_STATE_EXPIRED', now()->subMinute()->toIso8601ZuluString()));
        $this->postJson('/v1/webhooks/google?token=secreto-rtdn', $body)->assertNoContent();

        $this->assertFalse(Entitlement::query()->where('install_id', $id)->sole()->store_premium);
        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => false]);
        $n = StoreNotification::query()->sole();
        $this->assertSame('refreshed:SUBSCRIPTION_STATE_EXPIRED', $n->result);
        $this->assertStringNotContainsString('token-de-prueba', json_encode($n->payload));
    }

    public function test_webhook_is_disabled_without_configured_token(): void
    {
        $this->postJson('/v1/webhooks/google?token=', ['message' => ['data' => '']])->assertStatus(403);
    }

    public function test_apple_webhook_is_stored(): void
    {
        $this->postJson('/v1/webhooks/apple', ['signedPayload' => 'eyJ...'])->assertNoContent();
        $this->assertSame('eyJ...', StoreNotification::query()->sole()->payload['signedPayload']);
    }
}
