<?php

namespace App\Services;

use App\Exceptions\StoreException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Cliente mínimo de la Google Play Developer API (androidpublisher v3) con una cuenta de servicio.
 *
 * El JWT (RS256) se firma aquí con openssl, se cambia por un token de acceso en oauth2.googleapis.com/token y ese token
 * se guarda en caché hasta un minuto antes de que caduque. Sin SDK de Google.
 */
class GooglePlayClient
{
    private const TOKEN_CACHE_KEY = 'mininoches.google.access_token';

    public function __construct(private readonly array $config) {}

    public function isConfigured(): bool
    {
        return $this->credentials() !== null && ! empty($this->config['package']);
    }

    public function packageName(): string
    {
        return (string) $this->config['package'];
    }

    /**
     * purchases.subscriptionsv2.get
     *
     * @throws StoreException 402 si Google no conoce el token; 503 si no se pudo consultar.
     */
    public function getSubscription(string $purchaseToken): array
    {
        $url = sprintf('%s/applications/%s/purchases/subscriptionsv2/tokens/%s',
            $this->config['api_base'], rawurlencode($this->packageName()), rawurlencode($purchaseToken));
        $response = $this->call(fn (string $token) => Http::withToken($token)->acceptJson()->timeout(15)->get($url));

        if (in_array($response->status(), [400, 404, 410], true)) {
            throw StoreException::invalid('Google Play no reconoce esta compra.');
        }
        if (! $response->successful()) {
            throw StoreException::unavailable("Google Play respondió {$response->status()}; reintente más tarde.");
        }

        return $response->json() ?? [];
    }

    /**
     * purchases.subscriptions.acknowledge (Google reembolsa las suscripciones sin confirmar a los 3 días).
     * Se intenta y, si falla, no bloquea: la app también confirma con completePurchase.
     */
    public function acknowledge(string $subscriptionId, string $purchaseToken): bool
    {
        $url = sprintf('%s/applications/%s/purchases/subscriptions/%s/tokens/%s:acknowledge',
            $this->config['api_base'], rawurlencode($this->packageName()), rawurlencode($subscriptionId), rawurlencode($purchaseToken));
        try {
            return $this->call(fn (string $token) => Http::withToken($token)->acceptJson()->timeout(15)->post($url, (object) []))
                ->successful();
        } catch (StoreException) {
            return false;
        }
    }

    /** Hace la llamada; si el token caducó (401), lo renueva una vez. */
    private function call(callable $send): Response
    {
        try {
            $response = $send($this->accessToken());
            if ($response->status() === 401) {
                Cache::forget(self::TOKEN_CACHE_KEY);
                $response = $send($this->accessToken());
            }

            return $response;
        } catch (ConnectionException $e) {
            throw StoreException::unavailable('No se pudo conectar con Google Play; reintente más tarde.');
        }
    }

    public function accessToken(): string
    {
        $cached = Cache::get(self::TOKEN_CACHE_KEY);
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }
        $creds = $this->credentials();
        if ($creds === null) {
            throw StoreException::unavailable('Google Play no está configurado en el servidor.');
        }

        try {
            $response = Http::asForm()->acceptJson()->timeout(15)->post($creds['token_uri'], [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $this->jwt($creds),
            ]);
        } catch (ConnectionException) {
            throw StoreException::unavailable('No se pudo conectar con Google para autenticarse.');
        }
        $token = $response->json('access_token');
        if (! $response->successful() || ! is_string($token)) {
            throw StoreException::unavailable('Google rechazó la cuenta de servicio (revise GOOGLE_SERVICE_ACCOUNT_JSON).');
        }
        $ttl = max(60, (int) $response->json('expires_in', 3600) - 60);
        Cache::put(self::TOKEN_CACHE_KEY, $token, $ttl);

        return $token;
    }

    /** JWT RS256 firmado con la clave privada de la cuenta de servicio. */
    public function jwt(array $creds): string
    {
        $now = time();
        $b64 = fn (string $s) => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
        $header = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claims = $b64(json_encode([
            'iss' => $creds['client_email'],
            'scope' => $this->config['scope'],
            'aud' => $creds['token_uri'],
            'iat' => $now,
            'exp' => $now + 3600,
        ]));
        $key = openssl_pkey_get_private($creds['private_key']);
        if ($key === false || ! openssl_sign("{$header}.{$claims}", $signature, $key, OPENSSL_ALGO_SHA256)) {
            throw StoreException::unavailable('La clave privada de la cuenta de servicio de Google no es válida.');
        }

        return "{$header}.{$claims}.".$b64($signature);
    }

    /** @return array{client_email: string, private_key: string, token_uri: string}|null */
    private function credentials(): ?array
    {
        $value = trim((string) ($this->config['service_account_json'] ?? ''));
        if ($value === '') {
            return null;
        }
        if (! str_starts_with($value, '{')) {
            if (! is_readable($value)) {
                return null;
            }
            $value = (string) file_get_contents($value);
        }
        $json = json_decode($value, true);
        if (! is_array($json) || empty($json['client_email']) || empty($json['private_key'])) {
            return null;
        }

        return [
            'client_email' => $json['client_email'],
            'private_key' => $json['private_key'],
            'token_uri' => $this->config['token_uri'],
        ];
    }
}
