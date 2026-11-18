<?php

namespace Tests\Feature;

use App\Models\RedeemCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class DeployHookTest extends TestCase
{
    use RefreshDatabase;

    public function test_sin_token_configurado_no_existe(): void
    {
        config(['mininoches.deploy_token' => '']);
        $this->postJson('/internal/deploy')->assertNotFound();
    }

    public function test_con_token_equivocado_se_niega(): void
    {
        config(['mininoches.deploy_token' => 'secreto-largo']);
        $this->withToken('otro')->postJson('/internal/deploy')->assertForbidden();
        $this->postJson('/internal/deploy')->assertForbidden();
    }

    public function test_con_el_token_corre_los_pasos(): void
    {
        config(['mininoches.deploy_token' => 'secreto-largo']);
        Artisan::shouldReceive('call')->times(5)->andReturn(0);
        Artisan::shouldReceive('output')->andReturn('');
        $this->withToken('secreto-largo')->postJson('/internal/deploy')
            ->assertOk()->assertJson(['ok' => true])->assertJsonCount(5, 'pasos');
    }

    public function test_crea_el_codigo_de_los_revisores(): void
    {
        config(['mininoches.deploy_token' => 'secreto-largo']);
        Artisan::shouldReceive('call')->times(10)->andReturn(0);
        Artisan::shouldReceive('output')->andReturn('');
        for ($i = 0; $i < 2; $i++) {
            $this->withToken('secreto-largo')->postJson('/internal/deploy', ['review_code' => 'mini-revisa-2026'])
                ->assertOk()->assertJsonCount(6, 'pasos');
        }
        $code = RedeemCode::query()->where('code', 'MINI-REVISA-2026')->sole();
        $this->assertTrue($code->active);
        $this->assertSame(1000, $code->max_uses);
    }

    public function test_rechaza_un_codigo_de_revisores_raro(): void
    {
        config(['mininoches.deploy_token' => 'secreto-largo']);
        Artisan::shouldReceive('call')->times(5)->andReturn(0);
        Artisan::shouldReceive('output')->andReturn('');
        $this->withToken('secreto-largo')->postJson('/internal/deploy', ['review_code' => 'a b'])->assertStatus(422);
    }
}
