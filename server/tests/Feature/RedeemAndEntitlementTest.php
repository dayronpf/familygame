<?php

namespace Tests\Feature;

use App\Models\RedeemCode;
use App\Services\EntitlementSigner;
use Tests\TestCase;

class RedeemAndEntitlementTest extends TestCase
{
    private function code(array $attrs = []): RedeemCode
    {
        return RedeemCode::query()->create($attrs + ['code' => 'MINI-ABCD-EFGH', 'days' => 30, 'max_uses' => 1, 'active' => true]);
    }

    public function test_entitlement_without_anything_is_signed_none(): void
    {
        $id = $this->installId();
        $res = $this->getJson('/v1/entitlements?installId='.$id)->assertOk()->assertJson([
            'installId' => $id, 'premium' => false, 'source' => 'none', 'productId' => null, 'expiresAt' => null,
        ]);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $res->json('issuedAt'));
        $this->assertSignatureValid($res->json());

        $this->getJson('/v1/entitlements?installId=no-valido')->assertStatus(422);
        $this->getJson('/v1/entitlements')->assertStatus(422);
    }

    public function test_redeem_ok_gives_days(): void
    {
        $this->code();
        $id = $this->installId();
        $res = $this->postJson('/v1/redeem', ['installId' => $id, 'code' => 'mini-abcd-efgh'])->assertOk()
            ->assertJson(['premium' => true, 'source' => 'code', 'productId' => null, 'trial' => false]);
        $this->assertSignatureValid($res->json());
        $this->assertEqualsWithDelta(now()->addDays(30)->timestamp, strtotime($res->json('expiresAt')), 5);
        $this->assertSame(1, RedeemCode::query()->sole()->uses_count);

        $this->getJson('/v1/entitlements?installId='.$id)->assertJson(['premium' => true, 'source' => 'code']);
    }

    public function test_unknown_code_is_404(): void
    {
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'NO-EXISTE'])
            ->assertStatus(404)->assertJson(['error' => 'unknown_code']);
    }

    public function test_used_expired_and_inactive_codes_are_409(): void
    {
        $this->code();
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'MINI-ABCD-EFGH'])->assertOk();
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'MINI-ABCD-EFGH'])
            ->assertStatus(409)->assertJson(['error' => 'code_used']);

        $this->code(['code' => 'VIEJO-1', 'expires_at' => now()->subDay()]);
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'VIEJO-1'])
            ->assertStatus(409)->assertJson(['error' => 'code_expired']);

        $this->code(['code' => 'APAGADO', 'active' => false]);
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'APAGADO'])
            ->assertStatus(409)->assertJson(['error' => 'code_used']);
    }

    public function test_same_install_cannot_reuse_a_multi_use_code(): void
    {
        $this->code(['max_uses' => 10]);
        $id = $this->installId();
        $this->postJson('/v1/redeem', ['installId' => $id, 'code' => 'MINI-ABCD-EFGH'])->assertOk();
        $this->postJson('/v1/redeem', ['installId' => $id, 'code' => 'MINI-ABCD-EFGH'])->assertStatus(409);
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'MINI-ABCD-EFGH'])->assertOk();
    }

    public function test_redeem_adds_days_on_top_of_existing_expiry(): void
    {
        $this->code(['code' => 'PRIMERO', 'days' => 30]);
        $this->code(['code' => 'SEGUNDO', 'days' => 10]);
        $id = $this->installId();
        $first = $this->postJson('/v1/redeem', ['installId' => $id, 'code' => 'PRIMERO'])->assertOk()->json('expiresAt');
        $second = $this->postJson('/v1/redeem', ['installId' => $id, 'code' => 'SEGUNDO'])->assertOk()->json('expiresAt');

        $this->assertSame(strtotime($first) + 10 * 86400, strtotime($second));
    }

    public function test_redeem_validates_body_and_is_strictly_rate_limited(): void
    {
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'a b'])->assertStatus(422);
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'ABCD', 'extra' => 1])->assertStatus(422);

        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'ADIVINA'.$i])->assertStatus(404);
        }
        $this->postJson('/v1/redeem', ['installId' => $this->installId(), 'code' => 'ADIVINA9'])->assertStatus(429);
    }

    public function test_signing_key_missing_is_a_clear_503(): void
    {
        config(['mininoches.signing_key' => null]);
        $this->app->forgetInstance(EntitlementSigner::class);
        $this->getJson('/v1/entitlements?installId='.$this->installId())
            ->assertStatus(503)->assertJson(['error' => 'store_unavailable']);
    }

    public function test_signature_is_over_the_canonical_string(): void
    {
        $this->code();
        $id = $this->installId();
        $e = $this->postJson('/v1/redeem', ['installId' => $id, 'code' => 'MINI-ABCD-EFGH'])->json();
        $canonical = "{$id}|1|code||{$e['expiresAt']}|{$e['issuedAt']}";
        $this->assertTrue(sodium_crypto_sign_verify_detached(base64_decode($e['signature']), $canonical, base64_decode($this->publicKey)));

        // Alterar cualquier campo invalida la firma.
        $this->assertFalse(sodium_crypto_sign_verify_detached(base64_decode($e['signature']), str_replace('|1|', '|0|', $canonical), base64_decode($this->publicKey)));
    }

    public function test_keys_command_prints_a_usable_pair(): void
    {
        $this->artisan('mininoches:keys')->expectsOutputToContain('ENTITLEMENT_SIGNING_KEY=')->assertSuccessful();
        $this->artisan('mininoches:keys --show')->expectsOutput($this->publicKey)->assertSuccessful();
    }
}
