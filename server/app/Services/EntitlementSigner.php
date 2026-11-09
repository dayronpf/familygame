<?php

namespace App\Services;

use App\Exceptions\StoreException;
use Carbon\CarbonImmutable;
use DateTimeInterface;
use RuntimeException;

/**
 * Firma los derechos con Ed25519 (ext-sodium).
 *
 * Cadena canónica: «installId|premium(0/1)|source|productId|expiresAt|issuedAt», con cadena vacía para los nulos y
 * fechas ISO-8601 en UTC con «Z» y sin fracciones (p. ej. 2026-11-08T21:15:00Z). La app verifica con la clave pública.
 */
class EntitlementSigner
{
    public function __construct(private readonly ?string $configuredKey) {}

    public static function ensureSodium(): void
    {
        if (! function_exists('sodium_crypto_sign_detached')) {
            throw new RuntimeException(
                'Mininoches necesita la extensión sodium de PHP para firmar los derechos (Ed25519). '
                .'Instálela o actívela (extension=sodium en php.ini) y vuelva a arrancar.'
            );
        }
    }

    /** @return array{secret: string, public: string} ambos en base64 */
    public static function generateKeypair(): array
    {
        self::ensureSodium();
        $pair = sodium_crypto_sign_keypair();

        return [
            'secret' => base64_encode(sodium_crypto_sign_secretkey($pair)),
            'public' => base64_encode(sodium_crypto_sign_publickey($pair)),
        ];
    }

    public static function iso(?DateTimeInterface $date): ?string
    {
        return $date ? CarbonImmutable::instance($date)->utc()->format('Y-m-d\TH:i:s\Z') : null;
    }

    public static function canonical(string $installId, bool $premium, string $source, ?string $productId, ?string $expiresAt, string $issuedAt): string
    {
        return implode('|', [$installId, $premium ? '1' : '0', $source, $productId ?? '', $expiresAt ?? '', $issuedAt]);
    }

    public function isConfigured(): bool
    {
        return $this->secretKey(false) !== null;
    }

    public function publicKey(): string
    {
        return base64_encode(sodium_crypto_sign_publickey_from_secretkey($this->secretKey()));
    }

    /**
     * Respuesta `Entitlement` del contrato a partir del derecho efectivo.
     *
     * @param  array{premium: bool, source: string, productId: ?string, expiresAt: ?DateTimeInterface, trial: bool, autoRenewing: bool}  $e
     */
    public function entitlement(string $installId, array $e): array
    {
        $issuedAt = self::iso(CarbonImmutable::now());
        $expiresAt = self::iso($e['expiresAt']);
        $message = self::canonical($installId, $e['premium'], $e['source'], $e['productId'], $expiresAt, $issuedAt);

        return [
            'installId' => $installId,
            'premium' => $e['premium'],
            'source' => $e['source'],
            'productId' => $e['productId'],
            'expiresAt' => $expiresAt,
            'trial' => $e['trial'],
            'autoRenewing' => $e['autoRenewing'],
            'issuedAt' => $issuedAt,
            'signature' => base64_encode(sodium_crypto_sign_detached($message, $this->secretKey())),
        ];
    }

    private function secretKey(bool $throw = true): ?string
    {
        self::ensureSodium();
        $raw = $this->configuredKey ? base64_decode($this->configuredKey, true) : false;
        if ($raw !== false && strlen($raw) === SODIUM_CRYPTO_SIGN_SEEDBYTES) {
            $raw = sodium_crypto_sign_secretkey(sodium_crypto_sign_seed_keypair($raw));
        }
        if ($raw === false || strlen($raw) !== SODIUM_CRYPTO_SIGN_SECRETKEYBYTES) {
            if (! $throw) {
                return null;
            }
            throw StoreException::unavailable(
                'El servidor no tiene una clave de firma válida (ENTITLEMENT_SIGNING_KEY). Genérela con «php artisan mininoches:keys».'
            );
        }

        return $raw;
    }
}
