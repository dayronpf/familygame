<?php

namespace App\Services\Apple;

use App\Exceptions\StoreException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Cliente mínimo de la App Store Server API, sin SDK.
 *
 * Autenticación: JWT ES256 firmado aquí con openssl y la clave .p8 de App Store Connect (issuer id, key id y bundle id).
 * Todo lo que Apple devuelve firmado (signedTransactionInfo, signedRenewalInfo) se verifica con AppleJwsVerifier antes
 * de usarlo; si no pasa, la compra se rechaza.
 *
 * Entorno: con APPLE_ENVIRONMENT=production se pregunta primero a producción y, si Apple responde 404 (transacción
 * desconocida), se repite en sandbox, como recomienda Apple (las compras de App Review y de TestFlight son de sandbox).
 */
class AppStoreClient
{
    public const PRODUCTION = 'production';

    public const SANDBOX = 'sandbox';

    private ?string $token = null;

    private int $tokenExpires = 0;

    public function __construct(private readonly array $config, private readonly AppleJwsVerifier $verifier) {}

    public function isConfigured(): bool
    {
        return ! empty($this->config['issuer_id']) && ! empty($this->config['key_id'])
            && ! empty($this->config['bundle_id']) && $this->privateKey() !== null;
    }

    public function bundleId(): string
    {
        return (string) $this->config['bundle_id'];
    }

    public function verifier(): AppleJwsVerifier
    {
        return $this->verifier;
    }

    /**
     * GET /inApps/v1/transactions/{transactionId}
     *
     * @return array{environment: string, transaction: array<string, mixed>}
     *
     * @throws StoreException 402 si Apple no conoce la transacción o la firma no vale; 503 si no se pudo consultar.
     */
    public function getTransaction(string $transactionId): array
    {
        [$env, $response] = $this->get('/inApps/v1/transactions/'.rawurlencode($transactionId));

        return ['environment' => $env, 'transaction' => $this->verified($response->json('signedTransactionInfo'))];
    }

    /**
     * GET /inApps/v1/subscriptions/{transactionId}: estado de cada suscripción del grupo, con la última transacción y la
     * información de renovación ya verificadas.
     *
     * @param  ?string  $environment  production | sandbox (el de la transacción, para no volver a probar los dos)
     * @return array{environment: string, bundleId: ?string, groups: list<array{subscriptionGroupIdentifier: ?string, lastTransactions: list<array{status: int, originalTransactionId: ?string, transaction: array, renewalInfo: ?array}>}>}
     */
    public function getSubscriptionStatuses(string $transactionId, ?string $environment = null): array
    {
        [$env, $response] = $this->get('/inApps/v1/subscriptions/'.rawurlencode($transactionId), $environment);

        $groups = [];
        foreach ((array) $response->json('data', []) as $group) {
            $last = [];
            foreach ((array) ($group['lastTransactions'] ?? []) as $item) {
                $last[] = [
                    'status' => (int) ($item['status'] ?? 0),
                    'originalTransactionId' => isset($item['originalTransactionId']) ? (string) $item['originalTransactionId'] : null,
                    'transaction' => $this->verified($item['signedTransactionInfo'] ?? null),
                    'renewalInfo' => isset($item['signedRenewalInfo']) ? $this->verified($item['signedRenewalInfo']) : null,
                ];
            }
            $groups[] = ['subscriptionGroupIdentifier' => $group['subscriptionGroupIdentifier'] ?? null, 'lastTransactions' => $last];
        }

        return ['environment' => $env, 'bundleId' => $response->json('bundleId'), 'groups' => $groups];
    }

    /** Entorno de la API a partir del campo `environment` de un JWS («Production», «Sandbox»). */
    public static function apiEnvironment(?string $jwsEnvironment): ?string
    {
        return match ($jwsEnvironment) {
            'Production' => self::PRODUCTION,
            'Sandbox' => self::SANDBOX,
            default => null,
        };
    }

    /** @return array{0: string, 1: Response} el entorno que respondió y la respuesta correcta */
    private function get(string $path, ?string $environment = null): array
    {
        if (! $this->isConfigured()) {
            throw StoreException::unavailable('La App Store no está configurada en el servidor (APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY).');
        }
        $envs = match (true) {
            $environment !== null => [$environment],
            $this->config['environment'] === self::SANDBOX => [self::SANDBOX],
            (bool) ($this->config['sandbox_fallback'] ?? true) => [self::PRODUCTION, self::SANDBOX],
            default => [self::PRODUCTION],
        };

        foreach ($envs as $i => $env) {
            $url = rtrim((string) $this->config['api_base'][$env], '/').$path;
            try {
                $response = Http::withToken($this->jwt())->acceptJson()->timeout(15)->get($url);
            } catch (ConnectionException) {
                throw StoreException::unavailable('No se pudo conectar con la App Store; reintente más tarde.');
            }
            if ($response->status() === 404 && $i < count($envs) - 1) {
                continue; // Apple: si producción no la conoce, probar en sandbox
            }
            if ($response->successful()) {
                return [$env, $response];
            }
            throw match (true) {
                in_array($response->status(), [400, 404], true) => StoreException::invalid('La App Store no reconoce esta compra.'),
                in_array($response->status(), [401, 403], true) => StoreException::unavailable(
                    'La App Store rechazó la clave del servidor (revise APPLE_ISSUER_ID, APPLE_KEY_ID y APPLE_PRIVATE_KEY).'),
                default => StoreException::unavailable("La App Store respondió {$response->status()}; reintente más tarde."),
            };
        }

        throw StoreException::invalid('La App Store no reconoce esta compra.');
    }

    private function verified(mixed $jws): array
    {
        if (! is_string($jws) || $jws === '') {
            throw StoreException::invalid('La App Store no devolvió la transacción firmada.');
        }
        try {
            return $this->verifier->verify($jws);
        } catch (AppleJwsException $e) {
            Log::warning('JWS de la App Store rechazado: '.$e->getMessage());
            throw StoreException::invalid('La firma de la App Store no es válida.');
        }
    }

    /** JWT ES256 para la App Store Server API (válido 20 minutos; Apple admite hasta 60). */
    public function jwt(): string
    {
        $now = time();
        if ($this->token !== null && $this->tokenExpires - 60 > $now) {
            return $this->token;
        }
        $key = $this->privateKey();
        if ($key === null) {
            throw StoreException::unavailable('La clave privada de App Store Connect (APPLE_PRIVATE_KEY) no es válida.');
        }
        $exp = $now + 1200;
        $header = Es256::b64url(json_encode(['alg' => 'ES256', 'kid' => $this->config['key_id'], 'typ' => 'JWT']));
        $claims = Es256::b64url(json_encode([
            'iss' => $this->config['issuer_id'],
            'iat' => $now,
            'exp' => $exp,
            'aud' => 'appstoreconnect-v1',
            'bid' => $this->bundleId(),
        ]));
        if (! openssl_sign("{$header}.{$claims}", $der, $key, OPENSSL_ALGO_SHA256)) {
            throw StoreException::unavailable('No se pudo firmar el JWT para la App Store.');
        }
        $this->tokenExpires = $exp;

        return $this->token = "{$header}.{$claims}.".Es256::b64url(Es256::derToRaw($der));
    }

    /** La clave .p8 (ruta o PEM; admite «\n» escritos en una sola línea). Debe ser EC P-256. */
    private function privateKey(): ?\OpenSSLAsymmetricKey
    {
        $value = trim((string) ($this->config['private_key'] ?? ''));
        if ($value === '') {
            return null;
        }
        if (! str_contains($value, '-----BEGIN')) {
            if (! is_readable($value)) {
                return null;
            }
            $value = (string) file_get_contents($value);
        }
        $key = openssl_pkey_get_private(str_replace('\n', "\n", $value));
        if ($key === false) {
            return null;
        }
        $details = openssl_pkey_get_details($key);

        return ($details['type'] ?? null) === OPENSSL_KEYTYPE_EC && ($details['ec']['curve_name'] ?? null) === 'prime256v1' ? $key : null;
    }
}
