<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CodeRedemption extends Model
{
    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['redeemed_at' => 'datetime'];
    }
}
