<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

/**
 * Gancho de despliegue: después de que GitHub Actions sube los archivos por FTP, llama aquí para terminar lo que FTP
 * no puede hacer (migraciones, cachés, importar los paquetes). Protegido con `MININOCHES_DEPLOY_TOKEN` (cabecera
 * `Authorization: Bearer …`); sin token configurado responde 404, como si no existiera.
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

        return response()->json(['ok' => true, 'pasos' => $out]);
    }
}
