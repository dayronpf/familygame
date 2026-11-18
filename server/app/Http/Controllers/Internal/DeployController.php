<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use App\Models\RedeemCode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

/**
 * Gancho de despliegue: después de que GitHub Actions sube los archivos por FTP, llama aquí para terminar lo que FTP
 * no puede hacer (migraciones, cachés, importar los paquetes). Protegido con `MININOCHES_DEPLOY_TOKEN` (cabecera
 * `Authorization: Bearer …`); sin token configurado responde 404, como si no existiera.
 *
 * Opcional: `review_code` en el cuerpo crea (o reactiva) el código para los revisores de las tiendas, que no pueden
 * pagar ni usar la prueba gratis. Viene de un secreto de GitHub: el repositorio es público y no puede llevarlo escrito.
 */
class DeployController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $token = (string) config('mininoches.deploy_token');
        if ($token === '') {
            abort(404);
        }
        if (! hash_equals($token, (string) $request->bearerToken())) {
            abort(403);
        }

        $steps = [
            ['migrate', ['--force' => true]],
            ['mininoches:import-packs', []],
            ['config:cache', []],
            ['route:cache', []],
            ['view:cache', []],
        ];
        $out = [];
        foreach ($steps as [$command, $args]) {
            $code = Artisan::call($command, $args);
            $out[] = ['comando' => $command, 'codigo' => $code, 'salida' => trim(Artisan::output())];
            if ($code !== 0) {
                return response()->json(['ok' => false, 'pasos' => $out], 500);
            }
        }

        $review = $request->json('review_code');
        if (is_string($review) && $review !== '') {
            $review = RedeemCode::normalize($review);
            if (! preg_match('/^[A-Z0-9-]{8,32}$/', $review)) {
                return response()->json(['ok' => false, 'pasos' => $out, 'error' => 'review_code no válido'], 422);
            }
            RedeemCode::query()->updateOrCreate(['code' => $review], [
                'days' => 3650, 'max_uses' => 1000, 'active' => true, 'expires_at' => null,
                'note' => 'Revisores de Google Play / App Store (secreto REVIEW_CODE)',
            ]);
            $out[] = ['comando' => 'review_code', 'codigo' => 0, 'salida' => 'listo'];
        }

        return response()->json(['ok' => true, 'pasos' => $out]);
    }
}
