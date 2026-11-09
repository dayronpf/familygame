<?php

namespace App\Http\Controllers\Api;

use App\Services\FeedbackIngestor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FeedbackController extends ApiController
{
    public function store(Request $request, FeedbackIngestor $ingestor): JsonResponse
    {
        $max = config('mininoches.feedback');
        $raw = $request->getContent();
        if (strlen($raw) > $max['max_bytes']) {
            return response()->json(['message' => 'Lote demasiado grande (máx. 64 KB).'], 413);
        }
        $body = json_decode($raw, true);
        if (! is_array($body) || array_is_list($body) || array_keys($body) !== ['events']
            || ! is_array($body['events']) || ! array_is_list($body['events']) || $body['events'] === []) {
            return response()->json(['message' => 'Cuerpo mal formado: se espera {"events": [...]}.'], 400);
        }
        if (count($body['events']) > $max['max_events']) {
            return response()->json(['message' => 'Lote demasiado grande (máx. 50 eventos).'], 413);
        }

        return response()->json($ingestor->ingest($body['events']), 202);
    }
}
