<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PackVersion extends Model
{
    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['manifest' => 'array', 'imported_at' => 'datetime'];
    }
}
