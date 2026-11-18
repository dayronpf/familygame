<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminSetupTest extends TestCase
{
    use RefreshDatabase;

    public function test_un_token_equivocado_no_existe(): void
    {
        $this->get('/admin/primer-acceso/otro')->assertNotFound();
        $this->post('/admin/primer-acceso/otro', [])->assertNotFound();
    }

    public function test_con_un_superadmin_el_enlace_ya_no_existe(): void
    {
        User::query()->create(['name' => 'A', 'email' => 'a@b.co', 'password' => 'una-clave-larga-1']);
        // Aunque el token fuera el bueno: con un SuperAdmin creado responde 404 antes de mirar nada más.
        $this->get('/admin/primer-acceso/'.str_repeat('0', 48))->assertNotFound();
    }

    public function test_el_token_bueno_crea_el_superadmin_una_sola_vez(): void
    {
        $token = (string) getenv('ADMIN_SETUP_TOKEN');
        if ($token === '') {
            $this->markTestSkipped('Solo en la máquina del dueño (ADMIN_SETUP_TOKEN).');
        }
        $this->get('/admin/primer-acceso/'.$token)->assertOk()->assertSee('Crear y entrar');
        $this->post('/admin/primer-acceso/'.$token, [
            'email' => 'Dueno@Ejemplo.com', 'password' => 'una-clave-larga-1', 'password_confirmation' => 'una-clave-larga-1',
        ])->assertRedirect(route('admin.dashboard'));
        $this->assertAuthenticated();
        $this->assertSame('dueno@ejemplo.com', User::query()->sole()->email);
        auth()->logout();
        $this->get('/admin/primer-acceso/'.$token)->assertNotFound();
    }
}
