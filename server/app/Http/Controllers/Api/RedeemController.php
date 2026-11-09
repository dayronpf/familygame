<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\StoreException;
use App\Models\CodeRedemption;
use App\Models\Entitlement;
use App\Models\RedeemCode;
use App\Services\EntitlementSigner;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RedeemController extends ApiController
{
    public function redeem(Request $request, EntitlementSigner $signer): JsonResponse
    {
        $this->rejectUnknownKeys($request, ['installId', 'code']);
        if (is_string($request->json('code'))) {
            $request->json()->set('code', RedeemCode::normalize($request->json('code')));
        }
        $data = $request->validate([
            'installId' => ['required', 'string', self::INSTALL_ID],
            'code' => ['required', 'string', 'regex:/^[A-Z0-9-]{4,32}$/'],
        ]);
        $signer->publicKey();

        $entitlement = DB::transaction(function () use ($data) {
            $code = RedeemCode::query()->where('code', $data['code'])->lockForUpdate()->first();
            if ($code === null) {
                throw new StoreException('unknown_code', 'Ese código no existe.', 404);
            }
            if (! $code->active) {
                throw new StoreException('code_used', 'Ese código está desactivado.', 409);
            }
            if ($code->expires_at && $code->expires_at->isPast()) {
                throw new StoreException('code_expired', 'Ese código ya caducó.', 409);
            }
            if ($code->uses_count >= $code->max_uses) {
                throw new StoreException('code_used', 'Ese código ya se usó.', 409);
            }
            if (CodeRedemption::query()->where('redeem_code_id', $code->id)->where('install_id', $data['installId'])->exists()) {
                throw new StoreException('code_used', 'Este teléfono ya usó ese código.', 409);
            }

            $now = CarbonImmutable::now();
            $entitlement = Entitlement::query()->lockForUpdate()->firstOrNew(['install_id' => $data['installId']]);
            // Suma los días sobre lo que ya tenga (código o suscripción), nunca los pierde.
            $current = $entitlement->exists ? $entitlement->effective($now) : Entitlement::none();
            $from = $current['premium'] && $current['expiresAt'] ? $current['expiresAt'] : $now;
            $entitlement->code_expires_at = $from->addDays($code->days);
            $entitlement->save();

            CodeRedemption::query()->create([
                'redeem_code_id' => $code->id, 'install_id' => $data['installId'], 'redeemed_at' => $now,
            ]);
            $code->increment('uses_count');

            return $entitlement;
        });

        return response()->json($signer->entitlement($data['installId'], $entitlement->effective()));
    }
}
