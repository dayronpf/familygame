<?php

namespace App\Providers;

use App\Services\EntitlementSigner;
use App\Services\GooglePlayClient;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(EntitlementSigner::class, fn () => new EntitlementSigner(config('mininoches.signing_key')));
        $this->app->singleton(GooglePlayClient::class, fn () => new GooglePlayClient(config('mininoches.google')));
    }

    public function boot(): void
    {
        // Sin sodium no se pueden firmar los derechos: mejor un error claro al arrancar que uno raro al comprar.
        EntitlementSigner::ensureSodium();

        if ($proxies = config('mininoches.trusted_proxies')) {
            TrustProxies::at($proxies === '*' ? '*' : array_map('trim', explode(',', $proxies)));
        }

        $limits = config('mininoches.rate_limits');
        foreach (['api', 'verify', 'redeem', 'feedback', 'webhooks'] as $name) {
            RateLimiter::for("mn-{$name}", fn (Request $request) => Limit::perMinute($limits[$name])
                ->by($name.':'.self::anonymousKey($request))
                ->response(fn () => response()->json(['message' => 'Demasiadas peticiones; espere un momento.'], 429)));
        }
    }

    /**
     * Clave del límite de ritmo: HMAC de la IP con APP_KEY. Solo vive en la caché el minuto que dura el límite;
     * la IP en claro no se escribe en ningún sitio.
     */
    public static function anonymousKey(Request $request): string
    {
        return hash_hmac('sha256', (string) $request->ip(), (string) config('app.key'));
    }
}
