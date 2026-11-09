@extends('layouts.admin')
@section('title', 'Compra '.$purchase->id)
@section('content')
<a href="{{ route('admin.purchases.index') }}" class="text-sm text-indigo-700 hover:underline">← Compras</a>
<h1 class="text-2xl font-semibold mt-2 mb-4">Compra {{ $purchase->id }}</h1>
<div class="grid md:grid-cols-2 gap-6">
    <section class="bg-white rounded-xl border border-slate-200 p-4 text-sm">
        <dl class="grid grid-cols-3 gap-y-1">
            <dt class="text-slate-500">Instalación</dt><dd class="col-span-2 font-mono text-xs">{{ $purchase->install_id }}</dd>
            <dt class="text-slate-500">Tienda</dt><dd class="col-span-2">{{ $purchase->platform === 'ios' ? 'App Store' : 'Google Play' }} ({{ $purchase->platform }}) {{ $purchase->test_purchase ? ($purchase->platform === 'ios' ? '(sandbox)' : '(compra de prueba)') : '' }}</dd>
            <dt class="text-slate-500">Producto</dt><dd class="col-span-2">{{ $purchase->product_id }} {{ $purchase->base_plan }}</dd>
            <dt class="text-slate-500">Estado</dt><dd class="col-span-2">{{ $purchase->state }}</dd>
            <dt class="text-slate-500">Premium</dt><dd class="col-span-2">{{ $purchase->premium ? 'Sí' : 'No' }} {{ $purchase->trial ? '(prueba gratis)' : '' }}</dd>
            <dt class="text-slate-500">Renovación</dt><dd class="col-span-2">{{ $purchase->auto_renewing ? 'Automática' : 'No' }}</dd>
            <dt class="text-slate-500">Fin</dt><dd class="col-span-2">{{ $purchase->expires_at?->format('d/m/Y H:i') ?? '—' }} (UTC)</dd>
            <dt class="text-slate-500">{{ $purchase->platform === 'ios' ? 'Hash de la transacción original' : 'Hash del token' }}</dt><dd class="col-span-2 font-mono text-xs break-all">{{ $purchase->token_hash }}</dd>
            @if ($purchase->transaction_id)<dt class="text-slate-500">Transacción</dt><dd class="col-span-2">{{ $purchase->transaction_id }}</dd>@endif
            <dt class="text-slate-500">Creada</dt><dd class="col-span-2">{{ $purchase->created_at->format('d/m/Y H:i') }}</dd>
            <dt class="text-slate-500">Verificada</dt><dd class="col-span-2">{{ $purchase->last_verified_at?->format('d/m/Y H:i') ?? '—' }}</dd>
        </dl>
        <h2 class="font-semibold mt-4 mb-1">Instalaciones con este derecho</h2>
        <ul class="font-mono text-xs">@forelse ($entitlements as $e)<li>{{ $e->install_id }}</li>@empty<li class="text-slate-500">Ninguna</li>@endforelse</ul>
        <h2 class="font-semibold mt-4 mb-1">Notificaciones</h2>
        <ul class="text-xs">@forelse ($notifications as $n)<li>{{ $n->created_at->format('d/m/Y H:i') }} · {{ $n->type }} · {{ $n->result }}</li>@empty<li class="text-slate-500">Ninguna</li>@endforelse</ul>
    </section>
    <section class="bg-white rounded-xl border border-slate-200 p-4">
        <h2 class="font-semibold mb-2">Respuesta de la tienda</h2>
        <pre class="text-xs bg-slate-900 text-slate-100 rounded-lg p-3 overflow-x-auto">{{ $purchase->raw_response ? json_encode($purchase->raw_response, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) : 'Sin respuesta (aún no verificada).' }}</pre>
    </section>
</div>
@endsection
