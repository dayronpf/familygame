<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Derecho de una instalación. Guarda lo que dice la tienda y lo que dan los códigos por separado, para que una
 * renovación de Google no borre los días regalados (ni al revés). El derecho efectivo es el que dure más.
 */
class Entitlement extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'store_premium' => 'boolean',
            'store_trial' => 'boolean',
            'store_auto_renewing' => 'boolean',
            'store_expires_at' => 'immutable_datetime',
            'code_expires_at' => 'immutable_datetime',
        ];
    }

    public function purchase(): BelongsTo
    {
        return $this->belongsTo(Purchase::class);
    }

    /**
     * @return array{premium: bool, source: string, productId: ?string, expiresAt: ?CarbonImmutable, trial: bool, autoRenewing: bool}
     */
    public function effective(?CarbonImmutable $now = null): array
    {
        $now ??= CarbonImmutable::now();
        $store = $this->store_premium && $this->store_source && $this->store_expires_at && $this->store_expires_at->greaterThan($now);
        $code = $this->code_expires_at && $this->code_expires_at->greaterThan($now);

        if ($code && (! $store || $this->code_expires_at->greaterThan($this->store_expires_at))) {
            return [
                'premium' => true, 'source' => 'code', 'productId' => null, 'expiresAt' => $this->code_expires_at,
                'trial' => false, 'autoRenewing' => false,
            ];
        }
        if ($store) {
            return [
                'premium' => true, 'source' => $this->store_source, 'productId' => $this->store_product_id,
                'expiresAt' => $this->store_expires_at, 'trial' => $this->store_trial,
                'autoRenewing' => $this->store_auto_renewing,
            ];
        }

        return self::none();
    }

    public static function none(): array
    {
        return [
            'premium' => false, 'source' => 'none', 'productId' => null, 'expiresAt' => null,
            'trial' => false, 'autoRenewing' => false,
        ];
    }
}
