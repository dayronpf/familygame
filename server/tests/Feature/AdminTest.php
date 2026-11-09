<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Premise;
use App\Models\RedeemCode;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AdminTest extends TestCase
{
    private function admin(): User
    {
        $this->artisan('mininoches:admin', ['email' => 'duena@mininoches.app', '--password' => 'una-clave-muy-larga'])->assertSuccessful();

        return User::query()->sole();
    }

    public function test_admin_command_creates_resets_and_refuses_a_second_admin(): void
    {
        $admin = $this->admin();
        $this->assertTrue(Hash::check('una-clave-muy-larga', $admin->password));

        $this->artisan('mininoches:admin', ['email' => 'duena@mininoches.app', '--password' => 'otra-clave-bien-larga'])
            ->expectsOutputToContain('restablecida')->assertSuccessful();
        $this->assertTrue(Hash::check('otra-clave-bien-larga', $admin->fresh()->password));

        $this->artisan('mininoches:admin', ['email' => 'intruso@mininoches.app', '--password' => 'una-clave-muy-larga'])
            ->expectsOutputToContain('Solo puede haber uno')->assertFailed();
        $this->assertSame(1, User::query()->count());

        $this->artisan('mininoches:admin', ['email' => 'duena@mininoches.app', '--password' => 'corta'])->assertFailed();
    }

    public function test_admin_command_asks_for_the_password_interactively(): void
    {
        $this->artisan('mininoches:admin', ['email' => 'duena@mininoches.app'])
            ->expectsQuestion('Contraseña (mínimo 12 caracteres)', 'clave-interactiva-1')
            ->expectsQuestion('Repita la contraseña', 'clave-interactiva-1')
            ->assertSuccessful();
        $this->assertTrue(Hash::check('clave-interactiva-1', User::query()->sole()->password));
    }

    public function test_login_logout_and_guest_redirect(): void
    {
        $this->admin();
        $this->get('/admin')->assertRedirect('/admin/login');
        $this->get('/admin/login')->assertOk()->assertSee('Contraseña');

        $this->post('/admin/login', ['email' => 'duena@mininoches.app', 'password' => 'mala'])->assertSessionHasErrors('email');
        $this->assertGuest();

        $this->post('/admin/login', ['email' => 'duena@mininoches.app', 'password' => 'una-clave-muy-larga'])->assertRedirect('/admin');
        $this->assertAuthenticated();
        $this->get('/admin')->assertOk()->assertSee('Suscriptores activos');

        $this->post('/admin/logout')->assertRedirect('/admin/login');
        $this->assertGuest();
    }

    public function test_login_is_throttled(): void
    {
        $this->admin();
        for ($i = 0; $i < 5; $i++) {
            $this->post('/admin/login', ['email' => 'duena@mininoches.app', 'password' => 'mala']);
        }
        $this->post('/admin/login', ['email' => 'duena@mininoches.app', 'password' => 'una-clave-muy-larga'])
            ->assertSessionHasErrors('email');
        $this->assertStringContainsString('Demasiados intentos', session('errors')->first('email'));
        $this->assertGuest();
    }

    public function test_there_is_no_public_registration(): void
    {
        $this->get('/register')->assertNotFound();
        $this->get('/admin/register')->assertNotFound();
        $this->post('/admin/register', ['email' => 'x@y.z'])->assertNotFound();
    }

    public function test_review_and_free_toggles_change_the_catalog(): void
    {
        $this->importPacks();
        $this->actingAs($this->admin());
        $campana = Premise::query()->where('ref', 'medieval:campana')->sole();
        $sombras = Premise::query()->where('ref', 'medieval:sombras')->sole();
        $v1 = $this->getJson('/v1/catalog')->json('version');

        // Las páginas se ven, con el texto de las variantes y las marcas resaltadas.
        $this->get('/admin/cuentos')->assertOk()->assertSee('La campana rota');
        $this->get('/admin/cuentos?pack=medieval&age=6-8&status=pendiente')->assertOk()->assertSee('La campana rota')->assertDontSee('Las sombras del cuarto');
        $this->get("/admin/cuentos/{$sombras->id}")->assertOk()
            ->assertSee('<mark class="token">{hero}</mark>', false)->assertSee('Encender la luz');

        $this->post("/admin/cuentos/{$campana->id}/revision", ['status' => 'rechazado', 'notes' => 'Da miedo'])->assertRedirect();
        $catalog = $this->getJson('/v1/catalog')->json();
        $this->assertSame(['medieval:campana'], $catalog['hiddenStories']);
        $this->assertNotSame($v1, $catalog['version']);
        $this->assertSame('Da miedo', $campana->fresh()->review_notes);

        $this->post("/admin/cuentos/{$campana->id}/revision", ['status' => 'aprobado'])->assertRedirect();
        $this->assertSame([], $this->getJson('/v1/catalog')->json('hiddenStories'));

        $this->post("/admin/cuentos/{$sombras->id}/gratis")->assertRedirect();
        $this->post("/admin/cuentos/{$campana->id}/gratis")->assertRedirect();
        $this->assertSame(['cosmos:chispa_perdida', 'mar:galletas_todos', 'medieval:campana'], $this->getJson('/v1/catalog')->json('freeStories'));

        $this->post("/admin/cuentos/{$campana->id}/revision", ['status' => 'cualquiera'])->assertSessionHasErrors('status');

        $this->assertSame(4, AuditLog::query()->where('action', 'like', 'story.%')->count());
    }

    public function test_codes_products_and_other_pages(): void
    {
        $this->importPacks();
        $this->actingAs($this->admin());

        $this->post('/admin/codigos', ['days' => 30, 'max_uses' => 5, 'quantity' => 3])->assertRedirect();
        $this->assertSame(3, RedeemCode::query()->count());
        $this->assertMatchesRegularExpression('/^MINI-[A-Z2-9]{4}-[A-Z2-9]{4}$/', RedeemCode::query()->first()->code);
        $this->post('/admin/codigos', ['code' => 'escuela-2026', 'days' => 60, 'max_uses' => 100])->assertRedirect();
        $this->assertTrue(RedeemCode::query()->where('code', 'ESCUELA-2026')->exists());
        $this->post('/admin/codigos', ['code' => 'ESCUELA-2026', 'days' => 60, 'max_uses' => 100])->assertSessionHasErrors('code');

        $code = RedeemCode::query()->where('code', 'ESCUELA-2026')->sole();
        $this->post("/admin/codigos/{$code->id}/activo")->assertRedirect();
        $this->assertFalse($code->fresh()->active);

        $this->post('/admin/productos', ['product_id' => 'mininoches_premium', 'platform' => 'ios', 'base_plan' => '', 'period' => 'P1Y', 'trial_days' => 7])
            ->assertRedirect();
        $this->assertCount(3, $this->getJson('/v1/catalog')->json('products'));

        foreach (['/admin', '/admin/compras', '/admin/codigos', '/admin/valoraciones', '/admin/productos', '/admin/auditoria'] as $url) {
            $this->get($url)->assertOk();
        }
    }

    public function test_admin_forms_carry_a_csrf_token(): void
    {
        // Las pruebas de Laravel no comprueban CSRF; se comprueba que cada formulario lleva su token.
        $this->importPacks();
        $this->actingAs($this->admin());
        $premise = Premise::query()->first();
        foreach (["/admin/cuentos/{$premise->id}", '/admin/codigos', '/admin/productos'] as $url) {
            $this->get($url)->assertOk()->assertSee('name="_token"', false);
        }
    }
}
