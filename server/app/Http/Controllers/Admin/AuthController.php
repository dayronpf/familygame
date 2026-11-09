<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Providers\AppServiceProvider;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class AuthController extends Controller
{
    public function show(): View
    {
        return view('admin.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $data = $request->validate(['email' => 'required|email', 'password' => 'required|string']);
        $key = 'admin-login:'.sha1(strtolower($data['email'])).':'.AppServiceProvider::anonymousKey($request);
        $max = (int) config('mininoches.rate_limits.admin_login', 5);

        if (RateLimiter::tooManyAttempts($key, $max)) {
            throw ValidationException::withMessages([
                'email' => 'Demasiados intentos. Espere '.RateLimiter::availableIn($key).' segundos.',
            ]);
        }
        if (! Auth::attempt(['email' => strtolower($data['email']), 'password' => $data['password']], $request->boolean('remember'))) {
            RateLimiter::hit($key, 60);
            throw ValidationException::withMessages(['email' => 'Correo o contraseña incorrectos.']);
        }

        RateLimiter::clear($key);
        $request->session()->regenerate();
        $request->user()->forceFill(['last_login_at' => now()])->save();
        AuditLog::record('login');

        return redirect()->intended(route('admin.dashboard'));
    }

    public function logout(Request $request): RedirectResponse
    {
        AuditLog::record('logout');
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
