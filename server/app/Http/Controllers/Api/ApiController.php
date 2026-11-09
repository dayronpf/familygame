<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

abstract class ApiController extends Controller
{
    public const INSTALL_ID = 'regex:/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/';

    /** El contrato usa `additionalProperties: false`: cualquier campo de más (p. ej. un nombre) es 422. */
    protected function rejectUnknownKeys(Request $request, array $allowed): void
    {
        $extra = array_diff(array_keys($request->json()->all()), $allowed);
        if ($extra !== []) {
            throw ValidationException::withMessages([
                reset($extra) => 'Campo no permitido: '.implode(', ', $extra),
            ]);
        }
    }
}
