<?php

namespace Database\Seeders;

use App\Models\Product;
use App\Models\Setting;
use App\Services\Catalog;
use Illuminate\Database\Seeder;

/**
 * Datos de partida: el producto de suscripción y la versión del catálogo.
 * Los cuentos se cargan con `php artisan mininoches:import-packs` (gratis por defecto: MININOCHES_DEFAULT_FREE).
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $plans = [
            ['base_plan' => 'anual', 'period' => 'P1Y', 'trial_days' => 7, 'position' => 1],
            ['base_plan' => 'mensual', 'period' => 'P1M', 'trial_days' => 7, 'position' => 2],
        ];
        foreach ($plans as $plan) {
            Product::query()->updateOrCreate(
                ['product_id' => 'mininoches_premium', 'platform' => 'android', 'base_plan' => $plan['base_plan']],
                $plan + ['active' => true]
            );
        }

        if (Setting::get(Catalog::VERSION_KEY) === null) {
            Setting::put(Catalog::VERSION_KEY, '1');
        }
    }
}
