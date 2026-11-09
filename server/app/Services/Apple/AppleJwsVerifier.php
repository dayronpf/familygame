<?php

namespace App\Services\Apple;

use Carbon\CarbonImmutable;
use InvalidArgumentException;
use OpenSSLCertificate;

/**
 * Verifica los JWS firmados por Apple (signedTransactionInfo, signedRenewalInfo y el signedPayload de App Store
 * Server Notifications v2). Nada de lo que traen se usa sin pasar por aquí.
 *
 * Comprueba, igual que la librería oficial de Apple (app-store-server-library):
 *  1. `alg` = ES256 y una cadena `x5c` de exactamente 3 certificados: hoja, intermedio y raíz.
 *  2. La raíz es una de las fijadas en el repositorio (por huella SHA-256; por defecto solo Apple Root CA - G3).
 *  3. El intermedio está firmado por esa raíz, es una CA y lleva el OID de Apple 1.2.840.113635.100.6.2.1.
 *  4. La hoja está firmada por el intermedio, usa una clave P-256 y lleva el OID 1.2.840.113635.100.6.11.1.
 *  5. Los tres certificados están vigentes ahora.
 *  6. La firma ES256 del JWS se verifica con la clave pública de la hoja.
 *
 * No consulta OCSP (la librería de Apple sí lo hace en modo «online»): ver docs/30.
 */
class AppleJwsVerifier
{
    public const LEAF_OID = '1.2.840.113635.100.6.11.1';

    public const INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

    /** @var array<string, OpenSSLCertificate> huella sha256 → raíz de confianza */
    private ?array $roots = null;

    /**
     * @param  list<string>  $rootCertificates  rutas a PEM o PEM en texto
     * @param  list<string>  $rootFingerprints  huellas SHA-256 (hex, con o sin «:») que se aceptan como raíz
     */
    public function __construct(private readonly array $rootCertificates, private readonly array $rootFingerprints) {}

    /**
     * @return array<string, mixed> el contenido (payload) del JWS ya verificado
     *
     * @throws AppleJwsException
     */
    public function verify(string $jws): array
    {
        $parts = explode('.', trim($jws));
        if (count($parts) !== 3) {
            throw new AppleJwsException('El JWS no tiene tres partes.');
        }
        [$h, $p, $s] = $parts;

        $header = $this->json($h, 'encabezado');
        if (($header['alg'] ?? null) !== 'ES256') {
            throw new AppleJwsException('El JWS no usa ES256.');
        }
        $x5c = $header['x5c'] ?? null;
        if (! is_array($x5c) || count($x5c) !== 3 || ! array_is_list($x5c)) {
            throw new AppleJwsException('El JWS no trae la cadena x5c de 3 certificados.');
        }
        [$leaf, $intermediate, $presentedRoot] = array_map(fn ($der) => $this->certificate($der), $x5c);

        $roots = $this->trustedRoots();
        $root = $roots[openssl_x509_fingerprint($presentedRoot, 'sha256')] ?? null;
        if ($root === null) {
            throw new AppleJwsException('La raíz de la cadena no es la de Apple.');
        }

        $now = CarbonImmutable::now()->getTimestamp();
        $this->assertValidAt($root, $now, 'raíz');
        $this->assertValidAt($intermediate, $now, 'intermedio');
        $this->assertValidAt($leaf, $now, 'hoja');

        if (openssl_x509_verify($intermediate, openssl_pkey_get_public($root)) !== 1) {
            throw new AppleJwsException('El certificado intermedio no está firmado por la raíz de Apple.');
        }
        $intInfo = openssl_x509_parse($intermediate);
        if (! $this->hasExtension($intInfo, self::INTERMEDIATE_OID)
            || ! str_contains((string) ($intInfo['extensions']['basicConstraints'] ?? ''), 'CA:TRUE')) {
            throw new AppleJwsException('El certificado intermedio no es el de Apple para StoreKit.');
        }

        if (openssl_x509_verify($leaf, openssl_pkey_get_public($intermediate)) !== 1) {
            throw new AppleJwsException('El certificado de firma no está firmado por el intermedio.');
        }
        if (! $this->hasExtension(openssl_x509_parse($leaf), self::LEAF_OID)) {
            throw new AppleJwsException('El certificado de firma no es el de App Store.');
        }
        $leafKey = openssl_pkey_get_public($leaf);
        $details = $leafKey ? openssl_pkey_get_details($leafKey) : false;
        if (! $details || $details['type'] !== OPENSSL_KEYTYPE_EC || ($details['ec']['curve_name'] ?? null) !== 'prime256v1') {
            throw new AppleJwsException('La clave del certificado de firma no es P-256.');
        }

        $raw = Es256::b64urlDecode($s);
        try {
            $der = $raw === false ? null : Es256::rawToDer($raw);
        } catch (InvalidArgumentException) {
            $der = null;
        }
        if ($der === null || openssl_verify("{$h}.{$p}", $der, $leafKey, OPENSSL_ALGO_SHA256) !== 1) {
            throw new AppleJwsException('La firma del JWS no es válida.');
        }

        return $this->json($p, 'contenido');
    }

    /** @return array<string, OpenSSLCertificate> */
    private function trustedRoots(): array
    {
        if ($this->roots !== null) {
            return $this->roots;
        }
        $allowed = array_map(fn ($f) => strtolower(str_replace(':', '', trim($f))), $this->rootFingerprints);
        $roots = [];
        foreach ($this->rootCertificates as $source) {
            $pem = str_contains($source, '-----BEGIN') ? $source : (is_readable($source) ? (string) file_get_contents($source) : '');
            $cert = $pem !== '' ? openssl_x509_read($pem) : false;
            if ($cert === false) {
                continue;
            }
            $fp = openssl_x509_fingerprint($cert, 'sha256');
            // Solo cuenta una raíz autofirmada cuya huella esté fijada.
            if (in_array($fp, $allowed, true) && openssl_x509_verify($cert, openssl_pkey_get_public($cert)) === 1) {
                $roots[$fp] = $cert;
            }
        }
        if ($roots === []) {
            throw new AppleJwsException('No hay una raíz de Apple de confianza configurada (resources/certs/AppleRootCA-G3.pem).');
        }

        return $this->roots = $roots;
    }

    private function certificate(mixed $base64Der): OpenSSLCertificate
    {
        $der = is_string($base64Der) ? base64_decode($base64Der, true) : false;
        $cert = $der ? openssl_x509_read("-----BEGIN CERTIFICATE-----\n".chunk_split(base64_encode($der), 64, "\n")."-----END CERTIFICATE-----\n") : false;
        if ($cert === false) {
            throw new AppleJwsException('Un certificado de la cadena x5c no se puede leer.');
        }

        return $cert;
    }

    private function assertValidAt(OpenSSLCertificate $cert, int $now, string $what): void
    {
        $info = openssl_x509_parse($cert);
        if (! $info || $now < (int) $info['validFrom_time_t'] || $now > (int) $info['validTo_time_t']) {
            throw new AppleJwsException("El certificado {$what} no está vigente.");
        }
    }

    private function hasExtension(array|false $info, string $oid): bool
    {
        return is_array($info) && array_key_exists($oid, $info['extensions'] ?? []);
    }

    private function json(string $segment, string $what): array
    {
        $decoded = Es256::b64urlDecode($segment);
        $data = $decoded === false ? null : json_decode($decoded, true);
        if (! is_array($data)) {
            throw new AppleJwsException("El {$what} del JWS no es JSON válido.");
        }

        return $data;
    }
}
