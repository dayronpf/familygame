<?php

namespace App\Console\Commands;

use App\Services\EntitlementSigner;
use Illuminate\Console\Command;

class KeysCommand extends Command
{
    protected $signature = 'mininoches:keys {--show : Solo muestra la clave pública de la clave configurada}';

    protected $description = 'Genera el par de claves Ed25519 con que se firman los derechos (o muestra la pública vigente)';

    public function handle(EntitlementSigner $signer): int
    {
        if ($this->option('show')) {
            if (! $signer->isConfigured()) {
                $this->error('ENTITLEMENT_SIGNING_KEY no está configurada o no es válida.');

                return self::FAILURE;
            }
            $this->line($signer->publicKey());

            return self::SUCCESS;
        }

        $pair = EntitlementSigner::generateKeypair();
        $this->info('Par de claves Ed25519 nuevo.');
        $this->newLine();
        $this->line('1) Copie esta línea en el .env del servidor (es SECRETA; no la suba al repositorio):');
        $this->line('ENTITLEMENT_SIGNING_KEY='.$pair['secret']);
        $this->newLine();
        $this->line('2) Clave pública para la app (no es secreta; va dentro de la app para verificar la firma):');
        $this->line($pair['public']);
        $this->newLine();
        $this->warn('Si cambia la clave, los derechos firmados con la anterior dejan de validar en las apps que aún tengan la pública vieja.');

        return self::SUCCESS;
    }
}
