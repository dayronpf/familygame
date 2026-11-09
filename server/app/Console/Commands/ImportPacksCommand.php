<?php

namespace App\Console\Commands;

use App\Services\PackImporter;
use Illuminate\Console\Command;
use RuntimeException;

class ImportPacksCommand extends Command
{
    protected $signature = 'mininoches:import-packs {--path= : Carpeta con {id}/pack.json (por defecto MININOCHES_PACKS_PATH o ../content/packs)}';

    protected $description = 'Importa o actualiza los cuentos de los packs sin tocar la revisión ni «Gratis»';

    public function handle(PackImporter $importer): int
    {
        $path = $this->option('path') ?: config('mininoches.packs_path');
        try {
            $result = $importer->import($path);
        } catch (RuntimeException $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $this->table(
            ['Pack', 'Versión', 'Cuentos', 'Nuevos', 'Retirados'],
            array_map(fn ($p) => [$p['id'], $p['version'], $p['premises'], $p['created'], $p['removed']], $result['packs'])
        );
        foreach ($result['skipped'] as $s) {
            $this->warn("Omitido: {$s}");
        }
        $this->info($result['catalogChanged'] ? 'El catálogo cambió: versión nueva.' : 'El catálogo no cambió.');

        return self::SUCCESS;
    }
}
