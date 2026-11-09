<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\StoreException;
use App\Models\Purchase;
use App\Models\StoreNotification;
use App\Services\GooglePlayClient;
use App\Services\PurchaseService;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

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

    /** App Store Server Notifications v2: por ahora solo se guarda (se verificará con la publicación en iOS). */
    public function apple(Request $request): Response
    {
        $payload = $request->json()->all();
        StoreNotification::query()->create([
            'platform' => 'ios',
            'type' => 'unverified',
            'payload' => ['signedPayload' => is_string($payload['signedPayload'] ?? null) ? $payload['signedPayload'] : null],
        ]);

        return response('', 204);
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
