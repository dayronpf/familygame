<?php

namespace Tests;

use App\Services\EntitlementSigner;
use App\Services\PackImporter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Str;

abstract class TestCase extends BaseTestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    /** Clave pública (base64) del par generado para cada prueba. */
    protected string $publicKey;

    protected function setUp(): void
    {
        parent::setUp();
        $pair = EntitlementSigner::generateKeypair();
        $this->publicKey = $pair['public'];
        config(['mininoches.signing_key' => $pair['secret'], 'mininoches.packs_path' => base_path('tests/Fixtures/packs')]);
        $this->app->forgetInstance(EntitlementSigner::class);
    }

    protected function importPacks(): array
    {
        return app(PackImporter::class)->import(config('mininoches.packs_path'));
    }

    /** Comprueba la firma Ed25519 de un derecho con la clave pública, como hará la app. */
    protected function assertSignatureValid(array $e): void
    {
        $message = EntitlementSigner::canonical($e['installId'], $e['premium'], $e['source'], $e['productId'], $e['expiresAt'], $e['issuedAt']);
        $this->assertTrue(
            sodium_crypto_sign_verify_detached(base64_decode($e['signature']), $message, base64_decode($this->publicKey)),
            "Firma inválida para «{$message}»"
        );
    }

    protected function installId(): string
    {
        return (string) Str::uuid(); // UUID v4
    }
}
