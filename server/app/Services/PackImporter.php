<?php

namespace App\Services;

use App\Models\Pack;
use App\Models\PackVersion;
use App\Models\Premise;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Lee `content/packs/{id}/pack.json` (esquema 2) y guarda packs, versiones y cuentos.
 *
 * Nunca pisa la revisión del SuperAdmin (estado, notas, «Gratis»): solo el texto y los datos del pack.
 */
class PackImporter
{
    public function __construct(private readonly Catalog $catalog) {}

    /**
     * @return array{packs: list<array{id: string, version: string, premises: int, created: int, removed: int}>, skipped: list<string>, catalogChanged: bool}
     */
    public function import(string $path): array
    {
        $dir = rtrim($path, '/');
        if (! is_dir($dir)) {
            throw new RuntimeException("No existe la carpeta de packs: {$dir}");
        }
        $files = glob($dir.'/*/pack.json') ?: [];
        sort($files);
        if ($files === []) {
            throw new RuntimeException("No hay ningún {id}/pack.json en {$dir}");
        }

        $before = $this->snapshot();
        $result = ['packs' => [], 'skipped' => [], 'catalogChanged' => false];

        DB::transaction(function () use ($files, &$result) {
            foreach ($files as $file) {
                $raw = file_get_contents($file);
                $json = json_decode($raw, true);
                if (! is_array($json) || ! isset($json['pack']['id'], $json['pack']['version'])) {
                    $result['skipped'][] = "{$file}: JSON inválido o sin «pack.id»/«pack.version»";

                    continue;
                }
                if ((int) ($json['pack']['schema'] ?? 0) !== 2 || ! is_array($json['premises'] ?? null)) {
                    $result['skipped'][] = "{$json['pack']['id']}: esquema {$json['pack']['schema']} (solo se importa el esquema 2)";

                    continue;
                }
                $result['packs'][] = $this->importPack($json, hash('sha256', $raw));
            }
        });

        if ($this->snapshot() !== $before) {
            $this->catalog->bump();
            $result['catalogChanged'] = true;
        }

        return $result;
    }

    private function importPack(array $json, string $sha): array
    {
        $meta = $json['pack'];
        $packId = $meta['id'];
        $version = $meta['version'];
        $now = now();

        Pack::query()->updateOrCreate(['id' => $packId], [
            'name' => $meta['name'] ?? $packId,
            'version' => $version,
            'schema' => (int) $meta['schema'],
            'language' => $meta['language'] ?? null,
            'age_band' => $meta['age_band'] ?? null,
            'morals' => array_map(fn ($m) => [
                'id' => $m['id'], 'name' => $m['name'] ?? $m['id'], 'text' => $m['text'] ?? null,
            ], $json['morals'] ?? []),
            'imported_at' => $now,
        ]);

        $fragments = [];
        $choices = [];
        $defaultFree = config('mininoches.default_free', []);
        $seen = [];
        $created = 0;

        foreach (array_values($json['premises']) as $position => $p) {
            $pid = $p['id'];
            $beats = [];
            $variantCount = 0;
            foreach ($p['beats'] ?? [] as $b) {
                $beat = ['id' => $b['id'], 'variants' => []];
                foreach ($b['variants'] ?? [] as $v) {
                    $fragments[] = "{$pid}.{$b['id']}.{$v['id']}";
                    $beat['variants'][] = ['id' => $v['id'], 'text' => $v['text'] ?? ''];
                    $variantCount++;
                }
                if (isset($b['choice']['id'])) {
                    $beat['choice'] = [
                        'id' => $b['choice']['id'],
                        'ask' => $b['choice']['ask'] ?? '',
                        'options' => array_map(fn ($o) => [
                            'id' => $o['id'], 'label' => $o['label'] ?? $o['id'],
                        ], $b['choice']['options'] ?? []),
                    ];
                    foreach ($b['choice']['options'] ?? [] as $o) {
                        $choices[] = "{$pid}.{$b['choice']['id']}.{$o['id']}";
                    }
                }
                $beats[] = $beat;
            }

            $ref = "{$packId}:{$pid}";
            $seen[] = $pid;
            $premise = Premise::query()->firstOrNew(['pack_id' => $packId, 'premise_id' => $pid]);
            if (! $premise->exists) {
                $premise->review_status = Premise::PENDING;
                $premise->is_free = in_array($ref, $defaultFree, true);
                $created++;
            }
            $premise->fill([
                'ref' => $ref,
                'title' => $p['title'] ?? $pid,
                'value' => $p['value'] ?? '',
                'ages' => $p['ages'] ?? [],
                'beats' => $beats,
                'beat_count' => count($beats),
                'variant_count' => $variantCount,
                'position' => $position,
                'pack_version' => $version,
                'in_pack' => true,
            ])->save();
        }

        $removed = Premise::query()->where('pack_id', $packId)->whereNotIn('premise_id', $seen)
            ->where('in_pack', true)->update(['in_pack' => false]);

        $castIds = [];
        foreach (['characters', 'places', 'props'] as $kind) {
            foreach ($json[$kind] ?? [] as $item) {
                if (isset($item['id'])) {
                    $castIds[] = $item['id'];
                }
            }
        }

        PackVersion::query()->updateOrCreate(['pack_id' => $packId, 'version' => $version], [
            'sha256' => $sha,
            'manifest' => [
                'fragments' => array_values(array_unique($fragments)),
                'choices' => array_values(array_unique($choices)),
                'values' => array_values(array_map(fn ($m) => $m['id'], $json['morals'] ?? [])),
                'castIds' => array_values(array_unique($castIds)),
            ],
            'imported_at' => $now,
        ]);

        return [
            'id' => $packId, 'version' => $version, 'premises' => count($seen),
            'created' => $created, 'removed' => $removed,
        ];
    }

    private function snapshot(): string
    {
        $c = $this->catalog->build();
        unset($c['version']);

        return json_encode($c);
    }
}
