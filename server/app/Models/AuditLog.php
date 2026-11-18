<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Auth;

class AuditLog extends Model
{
    public const UPDATED_AT = null;

    protected $guarded = [];

    /** Nombre legible de cada acción (para el panel). */
    public const LABELS = [
        'login' => 'Entró al panel',
        'logout' => 'Salió del panel',
        'packs.import' => 'Leyó los packs',
        'story.create' => 'Creó un cuento',
        'story.edit' => 'Guardó un borrador',
        'story.queue' => 'Mandó a publicar',
        'story.queue_all' => 'Mandó a publicar todo',
        'story.published' => 'Se publicó',
        'story.publish_failed' => 'Falló la publicación',
        'story.discard' => 'Descartó cambios',
        'story.delete' => 'Eliminó un cuento',
        'story.restore' => 'Canceló la eliminación',
        'story.review' => 'Revisó un cuento',
        'story.free' => 'Cambió «Gratis»',
        'story.bulk' => 'Acción en lote',
        'code.create' => 'Creó códigos',
        'code.activate' => 'Activó un código',
        'code.deactivate' => 'Desactivó un código',
        'product.create' => 'Creó un producto',
        'product.update' => 'Cambió un producto',
        'product.activate' => 'Activó un producto',
        'product.deactivate' => 'Desactivó un producto',
    ];

    public static function label(string $action): string
    {
        return self::LABELS[$action] ?? $action;
    }

    protected function casts(): array
    {
        return ['details' => 'array', 'created_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function record(string $action, ?Model $subject = null, array $details = []): void
    {
        static::query()->create([
            'user_id' => Auth::id(),
            'action' => $action,
            'subject_type' => $subject ? class_basename($subject) : null,
            'subject_id' => $subject ? (string) $subject->getKey() : null,
            'details' => $details ?: null,
        ]);
    }
}
