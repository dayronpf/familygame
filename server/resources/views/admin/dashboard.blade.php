@extends('layouts.admin')
@section('title', 'Inicio')
@section('content')
<x-page-header title="Hola 👋" subtitle="Así va Mininoches hoy." />

<div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
    <x-stat label="Suscriptores activos" :value="$stats['subscribers']" hint="pagando, sin contar pruebas" icon="card" tone="green" :href="route('admin.purchases.index', ['estado' => 'premium'])" />
    <x-stat label="En prueba gratis" :value="$stats['trials']" hint="prueba de 7 días en curso" icon="gift" tone="violet" :href="route('admin.purchases.index', ['estado' => 'prueba'])" />
    <x-stat label="Compras (30 días)" :value="$stats['purchases30']" hint="verificadas o intentadas" icon="card" tone="blue" :href="route('admin.purchases.index')" />
    <x-stat label="Valoraciones" :value="$stats['ratings']" :hint="$stats['ratingAvg'] ? 'promedio '.number_format($stats['ratingAvg'], 1, ',', '').' de 5' : 'aún sin datos'" icon="star" tone="amber" :href="route('admin.ratings.index')" />
</div>

<div class="grid lg:grid-cols-3 gap-6">
    <x-card title="Cuentos" class="lg:col-span-2">
        <x-slot:actions>
            <x-btn variant="secondary" size="sm" icon="plus" :href="route('admin.stories.create')">Nuevo cuento</x-btn>
            <x-btn variant="ghost" size="sm" :href="route('admin.stories.index')">Ver todos</x-btn>
        </x-slot:actions>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            @php
                $tiles = [
                    ['En la app', $stats['inApp'], ['vista' => 'app']],
                    ['Gratis', $stats['free'], ['gratis' => '1']],
                    ['Por revisar', $stats['pending'], ['vista' => 'pendientes']],
                    ['Ocultos', $stats['rejected'], ['vista' => 'ocultos']],
                ];
            @endphp
            @foreach ($tiles as [$label, $value, $params])
                <a href="{{ route('admin.stories.index', $params) }}" class="rounded-xl ring-1 ring-slate-200 p-3 hover:ring-brand-300 hover:bg-slate-50">
                    <div class="text-xs text-slate-500">{{ $label }}</div>
                    <div class="text-2xl font-semibold tabular-nums mt-1">{{ $value }}</div>
                </a>
            @endforeach
        </div>
        @if ($stats['drafts'])
            <a href="{{ route('admin.stories.index', ['vista' => 'cambios']) }}" class="mt-4 flex items-center gap-2 rounded-xl px-4 py-3 text-sm {{ $stats['failed'] ? 'bg-rose-50 text-rose-800' : 'bg-brand-50 text-brand-800' }}">
                <x-icon :name="$stats['failed'] ? 'alert' : 'pencil'" class="w-4 h-4" />
                {{ $stats['drafts'] }} {{ $stats['drafts'] === 1 ? 'cuento tiene' : 'cuentos tienen' }} cambios sin publicar @if ($stats['failed']) ({{ $stats['failed'] }} con error)@endif.
                <span class="ml-auto underline">Revisar</span>
            </a>
        @endif

        <h3 class="font-medium text-slate-800 mt-6 mb-2">Peor valorados <span class="text-xs font-normal text-slate-500">(con 3 o más valoraciones)</span></h3>
        @forelse ($lowRated as $r)
            @php $ref = $r->pack_id.':'.$r->premise_id; @endphp
            <a href="{{ isset($ids[$ref]) ? route('admin.stories.show', ['premise' => $ids[$ref], 'vista' => 'valoraciones']) : '#' }}" class="flex items-center gap-3 py-2 border-t border-slate-100 text-sm hover:text-brand-700">
                <span class="flex-1">{{ $titles[$ref] ?? $ref }}</span>
                <span class="inline-flex items-center gap-1"><x-icon name="star" class="w-4 h-4 text-amber-400" />{{ number_format($r->avg, 1, ',', '') }}</span>
                <span class="text-slate-400 text-xs w-16 text-right">{{ $r->n }} votos</span>
            </a>
        @empty
            <p class="text-sm text-slate-500">Aún no hay suficientes valoraciones.</p>
        @endforelse
    </x-card>

    <div class="space-y-6">
        <x-card title="Estado del servidor">
            @php
                $checks = [
                    [$signerOk, 'Firma de derechos', 'Firma lo que la app desbloquea.', 'ENTITLEMENT_SIGNING_KEY'],
                    [$googleOk, 'Google Play', 'Sin esto no se pueden verificar las compras de Android.', 'GOOGLE_SERVICE_ACCOUNT_JSON'],
                    [$rtdnOk, 'Avisos de Google', 'Renovaciones y cancelaciones al momento.', 'GOOGLE_RTDN_TOKEN'],
                    [$appleOk, 'App Store', 'Para la versión de iPhone (más adelante).', 'APPLE_*'],
                ];
            @endphp
            <ul class="space-y-3">
                @foreach ($checks as [$ok, $label, $help, $env])
                    <li class="flex gap-3">
                        <span class="mt-0.5 w-5 h-5 shrink-0 rounded-full flex items-center justify-center {{ $ok ? 'bg-emerald-100 text-emerald-600' : 'bg-amber-100 text-amber-600' }}"><x-icon :name="$ok ? 'check' : 'alert'" class="w-3.5 h-3.5" /></span>
                        <div class="text-sm"><div class="font-medium text-slate-800">{{ $label }} <span class="font-normal text-slate-500">{{ $ok ? '· listo' : '· falta configurar' }}</span></div>
                            <div class="text-xs text-slate-500">{{ $help }} <code class="text-[11px]">{{ $env }}</code></div></div>
                    </li>
                @endforeach
            </ul>
        </x-card>

        <x-card title="Catálogo de la app">
            <dl class="text-sm space-y-2">
                <div class="flex justify-between"><dt class="text-slate-500">Versión</dt><dd class="font-medium">{{ $catalog['version'] }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Cuentos gratis</dt><dd>{{ count($catalog['freeStories']) }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Cuentos ocultos</dt><dd>{{ count($catalog['hiddenStories']) }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Productos activos</dt>
                    <dd>@if (count($catalog['products']))<a class="text-brand-700 hover:underline" href="{{ route('admin.products.index') }}">{{ count($catalog['products']) }}</a>@else<a class="text-amber-700 hover:underline" href="{{ route('admin.products.index') }}">Ninguno · configurar</a>@endif</dd></div>
            </dl>
            <p class="text-xs text-slate-500 mt-3">La app lo consulta una vez al día; cada cambio del panel sube la versión.</p>
            <h3 class="font-medium text-sm mt-4 mb-2">Mundos</h3>
            <ul class="text-sm space-y-1">
                @forelse ($packs as $pack)
                    <li class="flex justify-between gap-2"><a href="{{ route('admin.stories.index', ['pack' => $pack->id]) }}" class="hover:text-brand-700">{{ $pack->name }}</a><span class="text-slate-400 text-xs">v{{ $pack->version }}</span></li>
                @empty
                    <li class="text-slate-500">Ninguno importado todavía.</li>
                @endforelse
            </ul>
        </x-card>
    </div>
</div>
@endsection
