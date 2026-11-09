<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Pack extends Model
{
    protected $primaryKey = 'id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return ['morals' => 'array', 'imported_at' => 'datetime'];
    }

    public function premises(): HasMany
    {
        return $this->hasMany(Premise::class, 'pack_id');
    }

    /** Nombre de una enseñanza por su id (o el id si no está). */
    public function moralName(string $id): string
    {
        foreach ($this->morals ?? [] as $m) {
            if (($m['id'] ?? null) === $id) {
                return $m['name'] ?? $id;
            }
        }

        return $id;
    }
}
