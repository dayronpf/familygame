<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RedeemCode extends Model
{
    /** Sin 0/O, 1/I/L para que se lea bien en papel. */
    public const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    protected $guarded = [];

    protected function casts(): array
    {
        return ['active' => 'boolean', 'expires_at' => 'datetime', 'days' => 'integer', 'max_uses' => 'integer', 'uses_count' => 'integer'];
    }

    public function redemptions(): HasMany
    {
        return $this->hasMany(CodeRedemption::class);
    }

    /** Código aleatorio legible, p. ej. MINI-7KQ2-XH9D. */
    public static function generate(): string
    {
        do {
            $part = fn () => implode('', array_map(
                fn () => self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)],
                range(1, 4)
            ));
            $code = 'MINI-'.$part().'-'.$part();
        } while (static::query()->where('code', $code)->exists());

        return $code;
    }

    public static function normalize(string $code): string
    {
        return strtoupper(trim($code));
    }
}
