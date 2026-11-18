<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/**
 * Primer acceso: crea el único SuperAdmin desde el navegador (en el hosting no hay consola para `mininoches:admin`).
 *
 * La dirección lleva un token; aquí solo está su huella sha256 (el repositorio es público). En cuanto existe un
 * SuperAdmin, la ruta responde 404 para siempre: el enlace sirve una sola vez.
 */
class SetupController extends Controller
{
    /** sha256 del token del enlace (el token está solo en credenciales/.env del dueño). */
    private const TOKEN_SHA256 = '04544cdf96de98d861bdb07383adfc1730e1936aa1c4c3c914db2e45f5f0243f';

    public function show(string $token): View
    {
        $this->guard($token);

        return view('admin.setup', ['token' => $token]);
    }

    public function store(Request $request, string $token): RedirectResponse
    {
        $this->guard($token);
        $data = $request->validate([
            'email' => 'required|email|max:190',
            'password' => 'required|string|min:12|confirmed',
        ], ['password.min' => 'La contraseña debe tener al menos 12 caracteres.', 'password.confirmed' => 'Las contraseñas no coinciden.']);

        $user = DB::transaction(function () use ($data) {
            abort_if(User::query()->lockForUpdate()->exists(), 404);

            return User::query()->create([
                'name' => 'SuperAdmin',
                'email' => strtolower(trim($data['email'])),
                'password' => $data['password'],
            ]);
        });

        Auth::login($user);
        $request->session()->regenerate();
        AuditLog::record('admin_created');

        return redirect()->route('admin.dashboard');
    }

    private function guard(string $token): void
    {
        abort_unless(hash_equals(self::TOKEN_SHA256, hash('sha256', $token)), 404);
        abort_if(User::query()->exists(), 404);
    }
}
