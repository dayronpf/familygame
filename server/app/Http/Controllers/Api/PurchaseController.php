<?php

namespace App\Http\Controllers\Api;

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

        $signer->publicKey(); // falla con 503 claro si no hay clave de firma, antes de llamar a la tienda
        $result = $data['platform'] === 'ios'
            ? $purchases->verifyApple($data['installId'], $data['productId'], $data['transactionId'])
            : $purchases->verifyGoogle($data['installId'], $data['productId'], $data['purchaseToken']);
        if ($result['error'] !== null) {
            throw $result['error'];
        }

        return response()->json($signer->entitlement($data['installId'], $result['entitlement']->effective()));
    }
}
