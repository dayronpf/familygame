<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Valoración anónima de un cuento (docs/12 §8). Sin instalación, IP ni hora. */
class StoryRating extends Model
{
    public const REASONS = [
        'no_sense' => 'No tuvo sentido',
        'repeated' => 'Se repitió',
        'length' => 'Muy largo o muy corto',
        'scary' => 'Dio miedo',
        'moral' => 'No me gustó la enseñanza',
    ];

    protected $primaryKey = 'event_id';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'cast_ids' => 'array',
            'fragment_ids' => 'array',
            'choices' => 'array',
            'reasons' => 'array',
            'rated_on' => 'date',
            'received_on' => 'date',
            'rating' => 'integer',
        ];
    }
}
