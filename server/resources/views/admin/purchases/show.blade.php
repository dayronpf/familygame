@extends('layouts.admin')
@section('title', 'Compra '.$purchase->id)
@section('content')
<x-page-header :title="'Compra #'.$purchase->id" :back="route('admin.purchases.index')" back-label="Compras">
    <x-slot:meta>
        <div class="flex flex-wrap gap-1.5 mt-2">
            <x-badge>{{ $purchase->platform === 'ios' ? 'App Store' : 'Google Play' }}</x-badge>
            @if ($purchase->premium)<x-badge :color="$purchase->trial ? 'violet' : 'green'" dot>{{ $purchase->trial ? 'Prueba gratis' : 'Activa' }}</x-badge>@else<x-badge dot>Sin acceso</x-badge>@endif
            @if ($purchase->test_purchase)<x-badge color="amber">{{ $purchase->platform === 'ios' ? 'Sandbox' : 'Compra de prueba' }}</x-badge>@endif
        </div>
    </x-slot:meta>
</x-page-header>
<div class="grid lg:grid-cols-2 gap-6">
    <div class="space-y-6">
        <x-card title="Detalles">
            <dl class="grid grid-cols-3 gap-y-2.5 text-sm">
                <dt class="text-slate-500">Producto</dt><dd class="col-span-2">{{ $purchase->product_id }} <span class="text-slate-500">{{ $purchase->base_plan }}</span></dd>
                <dt class="text-slate-500">Estado</dt><dd class="col-span-2 font-mono text-xs">{{ $purchase->state }}</dd>
                <dt class="text-slate-500">Renovación</dt><dd class="col-span-2">{{ $purchase->auto_renewing ? 'Automática' : 'No se renueva' }}</dd>
                <dt class="text-slate-500">Vence</dt><dd class="col-span-2">{{ $purchase->expires_at?->format('d/m/Y H:i') ?? '—' }} <span class="text-slate-400">UTC</span></dd>
                <dt class="text-slate-500">Instalación</dt><dd class="col-span-2 font-mono text-xs break-all">{{ $purchase->install_id }}</dd>
                <dt class="text-slate-500">{{ $purchase->platform === 'ios' ? 'Hash de la transacción original' : 'Hash del token' }}</dt><dd class="col-span-2 font-mono text-xs break-all">{{ $purchase->token_hash }}</dd>
                @if ($purchase->transaction_id)<dt class="text-slate-500">Transacción</dt><dd class="col-span-2">{{ $purchase->transaction_id }}</dd>@endif
                <dt class="text-slate-500">Creada</dt><dd class="col-span-2">{{ $purchase->created_at->format('d/m/Y H:i') }}</dd>
                <dt class="text-slate-500">Verificada</dt><dd class="col-span-2">{{ $purchase->last_verified_at?->format('d/m/Y H:i') ?? '—' }}</dd>
            </dl>
        </x-card>
        <x-card title="Teléfonos con este acceso">
            <ul class="font-mono text-xs space-y-1">@forelse ($entitlements as $e)<li>{{ $e->install_id }}</li>@empty<li class="text-slate-500 font-sans">Ninguno</li>@endforelse</ul>
        </x-card>
        <x-card title="Avisos de la tienda">
            <ul class="text-sm divide-y divide-slate-100">@forelse ($notifications as $n)<li class="py-1.5 flex gap-3"><span class="text-slate-500">{{ $n->created_at->format('d/m/Y H:i') }}</span><span class="font-mono text-xs">{{ $n->type }}</span><span class="ml-auto text-slate-500">{{ $n->result }}</span></li>@empty<li class="text-slate-500">Ninguno</li>@endforelse</ul>
        </x-card>
    </div>
    <x-card title="Respuesta de la tienda" subtitle="Lo último que devolvió la tienda al verificar.">
        <pre class="text-xs bg-night-950 text-indigo-100 rounded-lg p-4 overflow-x-auto max-h-[36rem]">{{ $purchase->raw_response ? json_encode($purchase->raw_response, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) : 'Sin respuesta (aún no verificada).' }}</pre>
    </x-card>
</div>
@endsection
