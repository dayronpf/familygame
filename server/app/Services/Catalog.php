<?php

namespace App\Services;

use App\Models\Premise;
use App\Models\Product;
use App\Models\Setting;

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
        ];
    }
}
