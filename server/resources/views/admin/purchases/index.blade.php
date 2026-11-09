@extends('layouts.admin')
@section('title', 'Compras y suscripciones')
@section('content')
<h1 class="text-2xl font-semibold mb-4">Compras y suscripciones</h1>
<form method="get" class="mb-4 flex gap-2">
    <input name="q" value="{{ $q }}" placeholder="installId, hash del token o el purchaseToken" class="border rounded-md px-3 py-1.5 w-full max-w-xl text-sm">
    <button class="rounded-md bg-indigo-700 text-white px-3 py-1.5 text-sm">Buscar</button>
    @if ($q !== '')<a href="{{ route('admin.purchases.index') }}" class="text-sm underline px-2 py-1.5">Limpiar</a>@endif
</form>
<p class="text-xs text-slate-500 mb-4">El token de compra se guarda cifrado; para buscar se usa su hash SHA-256. Si pega el token, el panel calcula el hash (no se guarda la búsqueda).</p>

<h2 class="font-semibold mb-2">Compras</h2>
<div class="bg-white rounded-xl border border-slate-200 overflow-x-auto mb-2">
<table class="w-full text-sm">
    <thead class="bg-slate-100 text-left text-slate-600"><tr>
        <th class="p-2">#</th><th class="p-2">Instalación</th><th class="p-2">Tienda</th><th class="p-2">Producto</th><th class="p-2">Estado</th><th class="p-2">Premium</th><th class="p-2">Fin</th><th class="p-2">Verificada</th></tr></thead>
    <tbody>
    @forelse ($purchases as $p)
        <tr class="border-t border-slate-100 hover:bg-slate-50">
            <td class="p-2"><a class="text-indigo-700 hover:underline" href="{{ route('admin.purchases.show', $p) }}">{{ $p->id }}</a></td>
            <td class="p-2 font-mono text-xs">{{ $p->install_id }}</td>
            <td class="p-2">{{ $p->platform }} @if ($p->test_purchase)<span class="text-xs bg-amber-100 rounded px-1">prueba</span>@endif</td>
            <td class="p-2">{{ $p->product_id }} <span class="text-slate-400">{{ $p->base_plan }}</span></td>
            <td class="p-2 text-xs">{{ str_replace('SUBSCRIPTION_STATE_', '', $p->state) }}</td>
            <td class="p-2">{{ $p->premium ? ($p->trial ? 'Sí (prueba)' : 'Sí') : 'No' }}</td>
            <td class="p-2">{{ $p->expires_at?->format('d/m/Y H:i') ?? '—' }}</td>
            <td class="p-2">{{ $p->last_verified_at?->format('d/m/Y H:i') ?? '—' }}</td>
        </tr>
    @empty
        <tr><td colspan="8" class="p-6 text-center text-slate-500">Sin compras.</td></tr>
    @endforelse
    </tbody>
</table>
</div>
<div class="mb-8">{{ $purchases->links() }}</div>

<h2 class="font-semibold mb-2">Derechos por instalación</h2>
<div class="bg-white rounded-xl border border-slate-200 overflow-x-auto mb-2">
<table class="w-full text-sm">
    <thead class="bg-slate-100 text-left text-slate-600"><tr>
        <th class="p-2">Instalación</th><th class="p-2">Premium ahora</th><th class="p-2">Origen</th><th class="p-2">Fin</th><th class="p-2">Tienda hasta</th><th class="p-2">Código hasta</th></tr></thead>
    <tbody>
    @forelse ($entitlements as $e)
        @php($eff = $e->effective())
        <tr class="border-t border-slate-100">
            <td class="p-2 font-mono text-xs">{{ $e->install_id }}</td>
            <td class="p-2">{{ $eff['premium'] ? ($eff['trial'] ? 'Sí (prueba)' : 'Sí') : 'No' }}</td>
            <td class="p-2">{{ $eff['source'] }}</td>
            <td class="p-2">{{ $eff['expiresAt']?->format('d/m/Y H:i') ?? '—' }}</td>
            <td class="p-2">{{ $e->store_expires_at?->format('d/m/Y H:i') ?? '—' }} @if ($e->purchase_id)<a class="text-indigo-700 text-xs hover:underline" href="{{ route('admin.purchases.show', $e->purchase_id) }}">compra {{ $e->purchase_id }}</a>@endif</td>
            <td class="p-2">{{ $e->code_expires_at?->format('d/m/Y H:i') ?? '—' }}</td>
        </tr>
    @empty
        <tr><td colspan="6" class="p-6 text-center text-slate-500">Sin derechos.</td></tr>
    @endforelse
    </tbody>
</table>
</div>
<div class="mb-8">{{ $entitlements->links() }}</div>

<h2 class="font-semibold mb-2">Últimas notificaciones de las tiendas</h2>
<ul class="text-sm bg-white rounded-xl border border-slate-200 divide-y">
    @forelse ($notifications as $n)
        <li class="p-2">{{ $n->created_at->format('d/m/Y H:i') }} · {{ $n->platform }} · {{ $n->type }} · <span class="text-slate-500">{{ $n->result ?? 'sin procesar' }}</span></li>
    @empty
        <li class="p-2 text-slate-500">Ninguna.</li>
    @endforelse
</ul>
@endsection
