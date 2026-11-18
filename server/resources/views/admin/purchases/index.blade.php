@extends('layouts.admin')
@section('title', 'Compras')
@section('content')
<x-page-header title="Compras y suscripciones" subtitle="Las compras que hicieron las familias en Google Play o en la App Store, y qué tiene desbloqueado cada teléfono." />

<form method="get" class="flex flex-wrap items-center gap-2 mb-4">
    @if ($tab !== 'compras')<input type="hidden" name="vista" value="{{ $tab }}">@endif
    <div class="relative flex-1 min-w-[18rem]">
        <x-icon name="search" class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input name="q" value="{{ $q }}" placeholder="Buscar por instalación, token de compra o transacción…" class="input pl-9">
    </div>
    <select name="tienda" class="input w-auto" onchange="this.form.submit()">
        <option value="">Todas las tiendas</option>
        <option value="android" @selected($platform === 'android')>Google Play</option>
        <option value="ios" @selected($platform === 'ios')>App Store</option>
    </select>
    <select name="estado" class="input w-auto" onchange="this.form.submit()">
        <option value="">Cualquier estado</option>
        <option value="premium" @selected($estado === 'premium')>Pagando</option>
        <option value="prueba" @selected($estado === 'prueba')>En prueba gratis</option>
        <option value="vencidas" @selected($estado === 'vencidas')>Vencidas o canceladas</option>
    </select>
    <x-btn variant="secondary" icon="search">Buscar</x-btn>
    @if ($q !== '' || $platform !== '' || $estado !== '')<x-btn variant="ghost" icon="x" :href="route('admin.purchases.index')">Limpiar</x-btn>@endif
</form>
<p class="text-xs text-slate-500 -mt-2 mb-4">El token de compra se guarda cifrado. Si pegas uno, el panel calcula su huella para buscarlo y no guarda la búsqueda.</p>

<div class="border-b border-slate-200 mb-4">
    <nav class="flex gap-6">
        @foreach (['compras' => ['Compras', $purchases->total()], 'derechos' => ['Por teléfono', $entitlements->total()], 'avisos' => ['Avisos de las tiendas', $notifications->total()]] as $key => [$label, $n])
            <a href="{{ request()->fullUrlWithQuery(['vista' => $key === 'compras' ? null : $key]) }}" class="tab {{ $tab === $key ? 'active' : '' }}">{{ $label }}
                <span class="rounded-full px-2 py-0.5 text-xs {{ $tab === $key ? 'bg-brand-100 text-brand-700' : 'bg-slate-100 text-slate-600' }}">{{ $n }}</span></a>
        @endforeach
    </nav>
</div>

@if ($tab === 'compras')
    <x-card :padding="false">
        <div class="overflow-x-auto">
        <table class="table-base">
            <thead><tr><th>#</th><th>Tienda</th><th>Producto</th><th>Estado</th><th>Vence</th><th>Instalación</th><th>Verificada</th><th></th></tr></thead>
            <tbody>
            @forelse ($purchases as $p)
                <tr>
                    <td class="tabular-nums text-slate-500">{{ $p->id }}</td>
                    <td class="whitespace-nowrap">{{ $p->platform === 'ios' ? 'App Store' : 'Google Play' }} @if ($p->test_purchase)<x-badge color="amber">prueba</x-badge>@endif</td>
                    <td><span class="font-medium">{{ $p->product_id }}</span> <span class="text-slate-400">{{ $p->base_plan }}</span></td>
                    <td class="whitespace-nowrap">
                        @if ($p->premium)<x-badge :color="$p->trial ? 'violet' : 'green'" dot>{{ $p->trial ? 'Prueba gratis' : 'Activa' }}</x-badge>@else<x-badge dot>Sin acceso</x-badge>@endif
                        <span class="block text-[11px] text-slate-400 font-mono mt-0.5">{{ str_replace(['SUBSCRIPTION_STATE_', 'APPLE_'], '', $p->state) }}</span>
                    </td>
                    <td class="whitespace-nowrap">{{ $p->expires_at?->format('d/m/Y H:i') ?? '—' }}</td>
                    <td class="font-mono text-[11px] text-slate-500 break-all max-w-[11rem]">{{ $p->install_id }}</td>
                    <td class="whitespace-nowrap text-slate-500">{{ $p->last_verified_at?->diffForHumans() ?? '—' }}</td>
                    <td class="text-right"><x-btn variant="ghost" size="sm" :href="route('admin.purchases.show', $p)">Ver</x-btn></td>
                </tr>
            @empty
                <tr><td colspan="8"><x-empty title="Sin compras." icon="card">Cuando alguien compre en la app, aparecerá aquí.</x-empty></td></tr>
            @endforelse
            </tbody>
        </table>
        </div>
    </x-card>
    <div class="mt-4">{{ $purchases->links() }}</div>
@elseif ($tab === 'derechos')
    <x-card :padding="false">
        <div class="overflow-x-auto">
        <table class="table-base">
            <thead><tr><th>Instalación</th><th>Acceso ahora</th><th>Por</th><th>Hasta</th><th>Tienda hasta</th><th>Código hasta</th></tr></thead>
            <tbody>
            @forelse ($entitlements as $e)
                @php $eff = $e->effective(); @endphp
                <tr>
                    <td class="font-mono text-xs">{{ $e->install_id }}</td>
                    <td>@if ($eff['premium'])<x-badge :color="$eff['trial'] ? 'violet' : 'green'" dot>{{ $eff['trial'] ? 'Prueba' : 'Completo' }}</x-badge>@else<x-badge dot>Gratis</x-badge>@endif</td>
                    <td>{{ ['store' => 'Suscripción', 'code' => 'Código', 'none' => '—'][$eff['source']] ?? $eff['source'] }}</td>
                    <td class="whitespace-nowrap">{{ $eff['expiresAt']?->format('d/m/Y H:i') ?? '—' }}</td>
                    <td class="whitespace-nowrap">{{ $e->store_expires_at?->format('d/m/Y') ?? '—' }} @if ($e->purchase_id)<a class="text-brand-700 text-xs hover:underline" href="{{ route('admin.purchases.show', $e->purchase_id) }}">compra #{{ $e->purchase_id }}</a>@endif</td>
                    <td class="whitespace-nowrap">{{ $e->code_expires_at?->format('d/m/Y') ?? '—' }}</td>
                </tr>
            @empty
                <tr><td colspan="6"><x-empty title="Ningún teléfono tiene acceso todavía." icon="card" /></td></tr>
            @endforelse
            </tbody>
        </table>
        </div>
    </x-card>
    <div class="mt-4">{{ $entitlements->links() }}</div>
@else
    <x-card :padding="false">
        <ul class="divide-y divide-slate-100 text-sm">
            @forelse ($notifications as $n)
                <li class="px-5 py-3 flex flex-wrap gap-x-4 gap-y-1">
                    <span class="text-slate-500 whitespace-nowrap">{{ $n->created_at->format('d/m/Y H:i') }}</span>
                    <span>{{ $n->platform === 'ios' ? 'App Store' : 'Google Play' }}</span>
                    <span class="font-mono text-xs">{{ $n->type }}</span>
                    <span class="ml-auto text-slate-500">{{ $n->result ?? 'sin procesar' }}</span>
                </li>
            @empty
                <li><x-empty title="Sin avisos de las tiendas." icon="refresh">Google y Apple avisan aquí de renovaciones, cancelaciones y reembolsos.</x-empty></li>
            @endforelse
        </ul>
    </x-card>
    <div class="mt-4">{{ $notifications->links() }}</div>
@endif
@endsection
