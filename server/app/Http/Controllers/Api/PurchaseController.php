<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\StoreException;
use App\Services\EntitlementSigner;
use App\Services\PurchaseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PurchaseController extends ApiController
{
    public function verify(Request $request, PurchaseService $purchases, EntitlementSigner $signer): JsonResponse
    {
        $this->rejectUnknownKeys($request, ['installId', 'platform', 'productId', 'purchaseToken', 'transactionId']);
        $data = $request->validate([
            'installId' => ['required', 'string', self::INSTALL_ID],
            'platform' => ['required', 'in:android,ios'],
            'productId' => ['required', 'string', 'max:100'],
            'purchaseToken' => ['required_if:platform,android', 'nullable', 'string', 'max:4096'],
            'transactionId' => ['required_if:platform,ios', 'nullable', 'string', 'max:100'],
        ]);

        if ($data['platform'] === 'ios') {
            $purchases->recordIos($data['installId'], $data['productId'], $data['transactionId']);
            // TODO(iOS): verificar con la App Store Server API cuando la app se publique en iOS.
            throw StoreException::unavailable('La verificación de compras de iOS aún no está disponible; se guardó y la app puede reintentar más tarde.');
        }

        $signer->publicKey(); // falla con 503 claro si no hay clave de firma, antes de llamar a Google
        $result = $purchases->verifyGoogle($data['installId'], $data['productId'], $data['purchaseToken']);
        if ($result['error'] !== null) {
            throw $result['error'];
        }

        return response()->json($signer->entitlement($data['installId'], $result['entitlement']->effective()));
    }
}
