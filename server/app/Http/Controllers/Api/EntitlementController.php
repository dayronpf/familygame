<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\StoreException;
use App\Models\Entitlement;
use App\Services\EntitlementSigner;
use App\Services\GooglePlayClient;
use App\Services\PurchaseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EntitlementController extends ApiController
{
    public function show(Request $request, EntitlementSigner $signer, PurchaseService $purchases, GooglePlayClient $google): JsonResponse
    {
        $data = $request->validate(['installId' => ['required', 'string', self::INSTALL_ID]]);
        $entitlement = Entitlement::query()->with('purchase')->where('install_id', $data['installId'])->first();

        // Si la suscripción de Google ya pasó su fecha (p. ej. se perdió la notificación de renovación), se reconsulta.
        $purchase = $entitlement?->purchase;
        if ($purchase && $purchase->platform === 'android' && $google->isConfigured()
            && (! $purchase->expires_at || $purchase->expires_at->isPast())
            && (! $purchase->last_verified_at || $purchase->last_verified_at->lt(now()->subMinutes(10)))) {
            try {
                $purchases->refreshGoogle($purchase);
                $entitlement->refresh();
            } catch (StoreException) {
                // Sin conexión con Google: se responde con lo guardado.
            }
        }

        return response()->json($signer->entitlement(
            $data['installId'],
            $entitlement?->effective() ?? Entitlement::none()
        ));
    }
}
