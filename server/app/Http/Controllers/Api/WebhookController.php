<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\StoreException;
use App\Models\Purchase;
use App\Models\StoreNotification;
use App\Services\Apple\AppleJwsException;
use App\Services\Apple\AppleJwsVerifier;
use App\Services\GooglePlayClient;
use App\Services\PurchaseService;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

class WebhookController extends ApiController
{
    /**
     * Google Real-time Developer Notifications por Pub/Sub (push). Se vuelve a consultar la compra a Google: el
     * contenido de la notificación solo dice «algo cambió».
     */
    public function google(Request $request, PurchaseService $purchases, GooglePlayClient $google): Response
    {
        $expected = (string) config('mininoches.google.rtdn_token');
        if ($expected === '' || ! hash_equals($expected, (string) $request->query('token'))) {
            return response('', 403);
        }

        $data = json_decode((string) base64_decode((string) $request->json('message.data'), true), true);
        if (! is_array($data)) {
            return response('', 204); // mensaje ilegible: se descarta (si no, Pub/Sub lo reintentaría para siempre)
        }

        $sub = $data['subscriptionNotification'] ?? null;
        $voided = $data['voidedPurchaseNotification'] ?? null;
        $token = $sub['purchaseToken'] ?? $voided['purchaseToken'] ?? null;
        $notification = StoreNotification::query()->create([
            'platform' => 'android',
            'type' => match (true) {
                $sub !== null => 'subscription:'.($sub['notificationType'] ?? '?'),
                $voided !== null => 'voided',
                isset($data['testNotification']) => 'test',
                default => 'other',
            },
            'token_hash' => is_string($token) ? Purchase::hashToken($token) : null,
            'payload' => $this->withoutToken($data),
        ]);

        $result = 'ignored';
        if (($data['packageName'] ?? null) !== $google->packageName()) {
            $result = 'other_package';
        } elseif (is_string($token)) {
            $purchase = Purchase::query()->where('platform', 'android')->where('token_hash', Purchase::hashToken($token))->first();
            if ($purchase === null) {
                $result = 'unknown_purchase'; // la app aún no la presentó; se verificará cuando lo haga
            } elseif (! $google->isConfigured()) {
                $result = 'store_unavailable';
            } else {
                try {
                    $purchases->refreshGoogle($purchase);
                    $result = 'refreshed:'.$purchase->state;
                } catch (StoreException $e) {
                    $notification->update(['result' => 'error:'.$e->errorCode, 'processed_at' => now()]);

                    return response('', 503); // Pub/Sub reintenta más tarde
                }
            }
        }
        $notification->update(['result' => $result, 'processed_at' => now()]);

        return response('', 204);
    }

    /**
     * App Store Server Notifications v2. Se verifica el JWS (`signedPayload`) con la cadena de Apple; si no vale, 400 y
     * no se guarda nada. Cada `notificationUUID` se procesa una sola vez. Apple reintenta si no recibe 200.
     */
    public function apple(Request $request, PurchaseService $purchases, AppleJwsVerifier $verifier): Response
    {
        $signed = $request->json('signedPayload');
        if (! is_string($signed) || $signed === '') {
            return response('', 400);
        }
        try {
            $payload = $verifier->verify($signed);
        } catch (AppleJwsException) {
            return response('', 400);
        }
        $uuid = $payload['notificationUUID'] ?? null;
        if (! is_string($uuid) || $uuid === '' || strlen($uuid) > 64) {
            return response('', 400);
        }
        if (StoreNotification::query()->where('platform', 'ios')->where('notification_id', $uuid)->exists()) {
            return response('', 200); // repetida: ya se procesó
        }

        try {
            DB::transaction(function () use ($payload, $uuid, $purchases) {
                $notification = StoreNotification::query()->create([
                    'platform' => 'ios',
                    'notification_id' => $uuid,
                    'type' => mb_substr(trim(($payload['notificationType'] ?? '?').':'.($payload['subtype'] ?? ''), ':'), 0, 60),
                    'payload' => $this->appleSummary($payload),
                ]);
                $outcome = $purchases->applyAppleNotification($payload);
                $notification->update([
                    'token_hash' => $outcome['tokenHash'],
                    'result' => mb_substr($outcome['result'], 0, 60),
                    'processed_at' => now(),
                ]);
            });
        } catch (AppleJwsException) {
            return response('', 400); // transacción o renovación de dentro mal firmadas: no se guarda
        } catch (UniqueConstraintViolationException) {
            return response('', 200); // la misma notificación llegó dos veces a la vez
        }

        return response('', 200);
    }

    /** Lo que se guarda de una notificación de Apple: sin los JWS de dentro (llevan los id de transacción). */
    private function appleSummary(array $payload): array
    {
        $data = (array) ($payload['data'] ?? []);

        return [
            'notificationType' => $payload['notificationType'] ?? null,
            'subtype' => $payload['subtype'] ?? null,
            'notificationUUID' => $payload['notificationUUID'] ?? null,
            'version' => $payload['version'] ?? null,
            'signedDate' => $payload['signedDate'] ?? null,
            'data' => array_intersect_key($data, array_flip(['bundleId', 'bundleVersion', 'environment', 'status', 'appAppleId'])),
        ];
    }

    /** El token de compra no se guarda en claro en las notificaciones (solo su hash). */
    private function withoutToken(array $data): array
    {
        foreach (['subscriptionNotification', 'voidedPurchaseNotification', 'oneTimeProductNotification'] as $k) {
            if (isset($data[$k]['purchaseToken'])) {
                $data[$k]['purchaseToken'] = '[sha256 en token_hash]';
            }
        }

        return $data;
    }
}
