<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Un cuento (premisa) de un pack.
 *
 * - `data` es la premisa publicada tal como está en content/packs/{pack}/pack.json; `beats` es su resumen para leer.
 * - `catalog` es su entrada en el catálogo fijo de la app (content/catalogo/lanzamiento-es.json): si es nula, el
 *   cuento existe en el pack pero la app no lo muestra.
 * - `draft` / `draft_catalog` son la versión editada en el panel. Se publica por la cola (docs/37): la importación del
 *   pack la limpia cuando lo publicado ya es igual al borrador.
 * La revisión y «Gratis» son del panel y la importación no los toca.
 */
class Premise extends Model
{
    public const PENDING = 'pendiente';

    public const APPROVED = 'aprobado';

    public const REJECTED = 'rechazado';

    public const STATUSES = [self::PENDING, self::APPROVED, self::REJECTED];

    public const AGES = ['2-3', '4-5', '6-8', '9-12'];

    public const DRAFT = 'borrador';

    public const QUEUED = 'en_cola';

    public const FAILED = 'error';

    public const PUBLISHING = 'publicando';

    public const CLEARED_DRAFT = [
        'draft' => null, 'draft_catalog' => null, 'draft_op' => null, 'draft_state' => null, 'draft_error' => null,
        'draft_updated_at' => null,
    ];

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'ages' => 'array',
            'beats' => 'array',
            'data' => 'array',
            'catalog' => 'array',
            'draft' => 'array',
            'draft_catalog' => 'array',
            'in_pack' => 'boolean',
            'is_free' => 'boolean',
            'reviewed_at' => 'datetime',
            'draft_updated_at' => 'datetime',
            'published_at' => 'datetime',
        ];
    }

    public function pack(): BelongsTo
    {
        return $this->belongsTo(Pack::class, 'pack_id');
    }

    public function clearDraft(): void
    {
        $this->fill(self::CLEARED_DRAFT);
        $this->published_at = now();
    }

    /** La premisa que se edita: el borrador si hay, si no la publicada. */
    public function editable(): array
    {
        return $this->draft ?? $this->data ?? ['id' => $this->premise_id, 'title' => $this->title, 'beats' => []];
    }

    public function editableCatalog(): ?array
    {
        return $this->draft !== null ? $this->draft_catalog : $this->catalog;
    }

    public function inApp(): bool
    {
        return $this->catalog !== null && $this->in_pack;
    }

    public function hasDraft(): bool
    {
        return $this->draft_state !== null;
    }

    /** Creado en el panel y nunca publicado: se puede borrar del todo. */
    public function isUnpublished(): bool
    {
        return $this->origin === 'panel' && $this->data === null;
    }

    /** Estado visible en la app, en una palabra. */
    public function visibility(): string
    {
        return match (true) {
            $this->isUnpublished() => 'nuevo',
            $this->review_status === self::REJECTED => 'oculto',
            ! $this->in_pack => 'retirado',
            $this->catalog === null => 'fuera',
            default => 'visible',
        };
    }

    public function scopeListed(Builder $q): Builder
    {
        return $q->where(fn ($w) => $w->where('in_pack', true)->orWhere('origin', 'panel'));
    }
}
