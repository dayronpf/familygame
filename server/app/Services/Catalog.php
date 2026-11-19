<?php

namespace App\Services;

use App\Models\Premise;
use App\Models\Product;
use App\Models\Setting;
use App\Models\StoryRating;

/**
 * Catálogo público: cuentos gratis, cuentos ocultos (rechazados) y productos. La versión sube con cada cambio del panel.
 */
class Catalog
{
    public const VERSION_KEY = 'catalog_version';

    public function version(): string
    {
        return Setting::get(self::VERSION_KEY, '1');
    }

    public function bump(): string
    {
        $next = (string) (((int) $this->version()) + 1);
        Setting::put(self::VERSION_KEY, $next);

        return $next;
    }

    public function build(): array
    {
        return [
            'version' => $this->version(),
            'freeStories' => Premise::query()
                ->where('is_free', true)->where('review_status', '!=', Premise::REJECTED)
                ->orderBy('ref')->pluck('ref')->values()->all(),
            'hiddenStories' => Premise::query()
                ->where('review_status', Premise::REJECTED)
                ->orderBy('ref')->pluck('ref')->values()->all(),
            'products' => Product::query()->where('active', true)
                ->orderBy('position')->orderBy('id')->get()
                ->map(fn (Product $p) => $p->toCatalog())->values()->all(),
            'ratings' => $this->ratings(),
        ];
    }

    /** Mínimo de valoraciones para enseñar la nota media de un cuento (con menos, una sola nota la decide). */
    public const MIN_RATINGS = 5;

    /**
     * Nota media de cada cuento (`pack:premisa` => {avg, n}), solo con al menos MIN_RATINGS valoraciones.
     * Va como objeto aunque esté vacío, para que la app siempre reciba el mismo formato.
     */
    public function ratings(): object
    {
        $rows = StoryRating::query()
            ->whereNotNull('premise_id')
            ->selectRaw('pack_id, premise_id, AVG(rating) as avg_rating, COUNT(*) as n')
            ->groupBy('pack_id', 'premise_id')
            ->havingRaw('COUNT(*) >= ?', [self::MIN_RATINGS])
            ->orderBy('pack_id')->orderBy('premise_id')
            ->get();
        $out = [];
        foreach ($rows as $r) {
            $out[$r->pack_id.':'.$r->premise_id] = [
                'avg' => round((float) $r->avg_rating, 1),
                'n' => (int) $r->n,
            ];
        }

        return (object) $out;
    }
}
