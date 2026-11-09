<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Entitlement;
use App\Models\Purchase;
use App\Models\StoreNotification;
use Illuminate\Http\Request;
use Illuminate\View\View;

class PurchaseController extends Controller
{
    public function index(Request $request): View
    {
        $q = trim((string) $request->query('q', ''));
        $platform = in_array($request->query('tienda'), ['android', 'ios'], true) ? $request->query('tienda') : '';
        $purchases = Purchase::query()->latest('id')->when($platform !== '', fn ($w) => $w->where('platform', $platform));
        $entitlements = Entitlement::query()->latest('updated_at');
        if ($q !== '') {
            // Se busca por installId, por el hash del token o por el token mismo (se calcula su hash; no se guarda).
            // En iOS el «token» es el originalTransactionId.
            $hashes = array_unique([strtolower($q), Purchase::hashToken($q)]);
            $purchases->where(fn ($w) => $w->where('install_id', strtolower($q))->orWhereIn('token_hash', $hashes)
                ->orWhere('transaction_id', $q));
            $entitlements->where(fn ($w) => $w->where('install_id', strtolower($q))
                ->orWhereIn('purchase_id', Purchase::query()->whereIn('token_hash', $hashes)->select('id')));
        }

        return view('admin.purchases.index', [
            'q' => $q,
            'platform' => $platform,
            'purchases' => $purchases->paginate(30, ['*'], 'compras')->withQueryString(),
            'entitlements' => $entitlements->paginate(30, ['*'], 'derechos')->withQueryString(),
            'notifications' => StoreNotification::query()->latest('id')->limit(10)->get(),
        ]);
    }

    public function show(Purchase $purchase): View
    {
        return view('admin.purchases.show', [
            'purchase' => $purchase,
            'entitlements' => Entitlement::query()->where('purchase_id', $purchase->id)->get(),
            'notifications' => $purchase->token_hash
                ? StoreNotification::query()->where('token_hash', $purchase->token_hash)->latest('id')->limit(50)->get()
                : collect(),
        ]);
    }
}
