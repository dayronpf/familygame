<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    public const PERIODS = ['P1M', 'P1Y'];

    public const PLATFORMS = ['android', 'ios'];

    protected $guarded = [];

    protected function casts(): array
    {
        return ['active' => 'boolean', 'trial_days' => 'integer', 'position' => 'integer'];
    }

    /** Cómo aparece en `GET /v1/catalog`. */
    public function toCatalog(): array
    {
        $out = ['id' => $this->product_id, 'platform' => $this->platform];
        if ($this->base_plan) {
            $out['basePlan'] = $this->base_plan;
        }
        $out['period'] = $this->period;
        $out['trialDays'] = $this->trial_days;

        return $out;
    }
}
