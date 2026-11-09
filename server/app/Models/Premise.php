<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Un cuento (premisa) importado de un pack. El texto se reemplaza en cada importación; la revisión y «Gratis» no.
 */
class Premise extends Model
{
    public const PENDING = 'pendiente';

    public const APPROVED = 'aprobado';

    public const REJECTED = 'rechazado';

    public const STATUSES = [self::PENDING, self::APPROVED, self::REJECTED];

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'ages' => 'array',
            'beats' => 'array',
            'in_pack' => 'boolean',
            'is_free' => 'boolean',
            'reviewed_at' => 'datetime',
        ];
    }

    public function pack(): BelongsTo
    {
        return $this->belongsTo(Pack::class, 'pack_id');
    }
}
