<?php

namespace Tests\Feature;

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
}
