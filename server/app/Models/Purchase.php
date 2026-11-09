<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Crypt;

class Purchase extends Model
{
    protected $guarded = [];

    protected $hidden = ['token_encrypted'];

    protected function casts(): array
    {
        return [
            'premium' => 'boolean',
            'trial' => 'boolean',
            'auto_renewing' => 'boolean',
            'test_purchase' => 'boolean',
            'expires_at' => 'datetime',
            'last_verified_at' => 'datetime',
            'raw_response' => 'array',
        ];
    }

    public static function hashToken(string $token): string
    {
        return hash('sha256', $token);
    }

    public function token(): ?string
    {
        return $this->token_encrypted ? Crypt::decryptString($this->token_encrypted) : null;
    }
}
