<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Premise;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Cola de publicación de cuentos (docs/37). La lee tools/content/publish_panel.py, que aplica cada cambio a
 * content/packs y al catálogo, valida con el motor, graba la voz, publica en R2, sube a git y responde aquí.
 * Protegido con el mismo token que el gancho de despliegue.
 */
class ContentQueueController extends Controller
{
    public function queue(Request $request): JsonResponse
    {
        $this->authorizeToken($request);
        $items = Premise::query()->where('draft_state', Premise::QUEUED)->orderBy('draft_updated_at')->get()
            ->map(fn (Premise $p) => [
                'ref' => $p->ref,
                'pack' => $p->pack_id,
                'id' => $p->premise_id,
                'op' => $p->draft_op ?? 'guardar',
                'premise' => $p->draft,
                'catalog' => $p->draft_op === 'eliminar' ? null : $p->draft_catalog,
                'free' => $p->is_free,
                'updatedAt' => $p->draft_updated_at?->toIso8601String(),
            ])->values();

        return response()->json(['items' => $items]);
    }

    public function result(Request $request): JsonResponse
    {
        $this->authorizeToken($request);
        $data = $request->validate([
            'results' => ['required', 'array', 'max:200'],
            'results.*.ref' => ['required', 'string', 'max:120'],
            'results.*.ok' => ['required', 'boolean'],
            'results.*.error' => ['nullable', 'string', 'max:5000'],
            'results.*.updatedAt' => ['nullable', 'string'],
        ]);
        $done = 0;
        foreach ($data['results'] as $r) {
            $premise = Premise::query()->where('ref', $r['ref'])->where('draft_state', Premise::QUEUED)->first();
            if ($premise === null) {
                continue;
            }
            // Si lo editaron otra vez mientras se publicaba, no se pisa el borrador nuevo.
            if (! empty($r['updatedAt']) && $premise->draft_updated_at?->toIso8601String() !== $r['updatedAt']) {
                continue;
            }
            if ($r['ok']) {
                $premise->draft_state = Premise::PUBLISHING; // la importación del despliegue lo limpia
                AuditLog::record('story.published', $premise, ['ref' => $premise->ref, 'op' => $premise->draft_op]);
            } else {
                $premise->draft_state = Premise::FAILED;
                $premise->draft_error = $r['error'] ?? 'Error desconocido al publicar.';
                AuditLog::record('story.publish_failed', $premise, ['ref' => $premise->ref, 'error' => mb_substr($premise->draft_error, 0, 500)]);
            }
            $premise->save();
            $done++;
        }

        return response()->json(['ok' => true, 'updated' => $done]);
    }

    private function authorizeToken(Request $request): void
    {
        $token = (string) config('mininoches.deploy_token');
        abort_if($token === '', 404);
        abort_unless(hash_equals($token, (string) $request->bearerToken()), 403);
    }
}
