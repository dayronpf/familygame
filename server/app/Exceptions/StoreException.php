<?php

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

/**
 * Error que la API devuelve con el formato `Error` del contrato: {"error": "...", "message": "..."}.
 */
class StoreException extends RuntimeException
{
    public function __construct(public readonly string $errorCode, string $message, public readonly int $status)
    {
        parent::__construct($message);
    }

    public static function unavailable(string $message): self
    {
        return new self('store_unavailable', $message, 503);
    }

    public static function invalid(string $message): self
    {
        return new self('invalid_purchase', $message, 402);
    }

    public static function expired(string $message): self
    {
        return new self('expired', $message, 402);
    }

    public function render(): JsonResponse
    {
        return response()->json(['error' => $this->errorCode, 'message' => $this->getMessage()], $this->status);
    }
}
