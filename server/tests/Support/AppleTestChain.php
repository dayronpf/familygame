<?php

namespace Tests\Support;

use App\Services\Apple\AppleJwsVerifier;
use App\Services\Apple\Es256;
use OpenSSLAsymmetricKey;

/**
 * Cadena de certificados desechable para las pruebas: raíz → intermedio → hoja, con los OID de Apple
 * (1.2.840.113635.100.6.2.1 en el intermedio y 1.2.840.113635.100.6.11.1 en la hoja), y JWS ES256 firmados con la
 * hoja como los de la App Store. La raíz de prueba se inyecta como raíz de confianza solo en las pruebas.
 */
final class AppleTestChain
{
    /** @var array<string, self> */
    private static array $cache = [];

    private function __construct(
        public readonly string $rootPem,
        public readonly string $intermediatePem,
        public readonly string $leafPem,
        private readonly OpenSSLAsymmetricKey $leafKey,
    ) {}

    /** Cadena válida (o sin alguno de los OID de Apple, para probar que se rechaza). */
    public static function make(bool $intermediateOid = true, bool $leafOid = true, string $name = 'principal', int $leafDays = 3650): self
    {
        $key = "{$name}:".(int) $intermediateOid.(int) $leafOid.":{$leafDays}";

        return self::$cache[$key] ??= self::build($intermediateOid, $leafOid, $name, $leafDays);
    }

    public function fingerprint(): string
    {
        return openssl_x509_fingerprint($this->rootPem, 'sha256');
    }

    /** JWS como los de Apple: cabecera {alg: ES256, x5c: [hoja, intermedio, raíz]} en base64 DER. */
    public function sign(array $payload, ?string $presentedRootPem = null, ?string $presentedIntermediatePem = null): string
    {
        // Los «presented» simulan cadenas falsas que meten certificados de confianza que no firmaron al siguiente.
        $x5c = array_map(fn (string $pem) => preg_replace('/-----[^-]+-----|\s+/', '', $pem),
            [$this->leafPem, $presentedIntermediatePem ?? $this->intermediatePem, $presentedRootPem ?? $this->rootPem]);
        $header = Es256::b64url(json_encode(['alg' => 'ES256', 'x5c' => $x5c]));
        $body = Es256::b64url(json_encode($payload));
        openssl_sign("{$header}.{$body}", $der, $this->leafKey, OPENSSL_ALGO_SHA256);

        return "{$header}.{$body}.".Es256::b64url(Es256::derToRaw($der));
    }

    private static function build(bool $intermediateOid, bool $leafOid, string $name, int $leafDays): self
    {
        $cnf = tempnam(sys_get_temp_dir(), 'mn-apple-cnf');
        $intExt = $intermediateOid ? AppleJwsVerifier::INTERMEDIATE_OID.' = ASN1:NULL' : '';
        $leafExt = $leafOid ? AppleJwsVerifier::LEAF_OID.' = ASN1:NULL' : '';
        file_put_contents($cnf, <<<CNF
            [req]
            distinguished_name = dn
            [dn]
            [v3_root]
            basicConstraints = critical,CA:TRUE
            keyUsage = critical,keyCertSign,cRLSign
            subjectKeyIdentifier = hash
            [v3_int]
            basicConstraints = critical,CA:TRUE,pathlen:0
            keyUsage = critical,keyCertSign,cRLSign
            {$intExt}
            [v3_leaf]
            basicConstraints = critical,CA:FALSE
            keyUsage = critical,digitalSignature
            {$leafExt}
            CNF);
        $ec = ['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1', 'config' => $cnf];
        $opts = fn (string $section) => ['digest_alg' => 'sha256', 'config' => $cnf, 'x509_extensions' => $section];

        $rootKey = openssl_pkey_new($ec);
        $root = openssl_csr_sign(openssl_csr_new(['commonName' => "Prueba Root CA ({$name})"], $rootKey, $opts('v3_root')),
            null, $rootKey, 3650, $opts('v3_root'), random_int(1, PHP_INT_MAX));
        $intKey = openssl_pkey_new($ec);
        $int = openssl_csr_sign(openssl_csr_new(['commonName' => 'Prueba WWDR CA'], $intKey, $opts('v3_int')),
            $root, $rootKey, 3650, $opts('v3_int'), random_int(1, PHP_INT_MAX));
        $leafKey = openssl_pkey_new($ec);
        $leaf = openssl_csr_sign(openssl_csr_new(['commonName' => 'Prueba StoreKit Signing'], $leafKey, $opts('v3_leaf')),
            $int, $intKey, $leafDays, $opts('v3_leaf'), random_int(1, PHP_INT_MAX));
        @unlink($cnf);

        openssl_x509_export($root, $rootPem);
        openssl_x509_export($int, $intPem);
        openssl_x509_export($leaf, $leafPem);

        return new self($rootPem, $intPem, $leafPem, $leafKey);
    }
}
