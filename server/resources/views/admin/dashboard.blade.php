@extends('layouts.admin')
@section('title', 'Panel')
@section('content')
<h1 class="text-2xl font-semibold mb-4">Panel</h1>

@php($cards = [
    ['Suscriptores activos', $stats['subscribers'], 'pagando, sin contar pruebas'],
    ['En prueba gratis', $stats['trials'], 'prueba de 7 días en curso'],
    ['Compras (30 días)', $stats['purchases30'], 'verificadas o intentadas'],
    ['Códigos canjeados', $stats['redemptions'], $stats['codeActive'].' con días vigentes'],
    ['Valoraciones', $stats['ratings'], $stats['ratingAvg'] ? 'promedio '.number_format($stats['ratingAvg'], 2, ',', '') : 'aún sin datos'],
    ['Cuentos por revisar', $stats['pending'], $stats['approved'].' aprobados · '.$stats['rejected'].' rechazados'],
])
<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 mb-8">
    @foreach ($cards as [$label, $value, $hint])
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-4">
            <div class="text-xs uppercase tracking-wide text-slate-500">{{ $label }}</div>
            <div class="text-3xl font-semibold mt-1">{{ $value }}</div>
            <div class="text-xs text-slate-500 mt-1">{{ $hint }}</div>
        </div>
    @endforeach
</div>

<div class="grid md:grid-cols-2 gap-6">
    <section class="bg-white rounded-xl shadow-sm border border-slate-200 p-4">
        <h2 class="font-semibold mb-3">Catálogo publicado (versión {{ $catalog['version'] }})</h2>
        <p class="text-sm mb-1"><b>Gratis:</b> {{ implode(', ', $catalog['freeStories']) ?: '—' }}</p>
        <p class="text-sm mb-1"><b>Ocultos:</b> {{ implode(', ', $catalog['hiddenStories']) ?: '—' }}</p>
        <p class="text-sm"><b>Productos:</b>
            @foreach ($catalog['products'] as $p) {{ $p['id'] }}/{{ $p['basePlan'] ?? '—' }} ({{ $p['period'] }}, {{ $p['trialDays'] }} días gratis)@if (! $loop->last), @endif @endforeach
        </p>
        <p class="text-xs text-slate-500 mt-3">La app lo pide en <code>GET /v1/catalog</code> como mucho una vez al día.</p>
    </section>
    <section class="bg-white rounded-xl shadow-sm border border-slate-200 p-4">
        <h2 class="font-semibold mb-3">Estado del servidor</h2>
        <ul class="text-sm space-y-1">
            <li>{{ $signerOk ? '✅' : '⚠️' }} Clave de firma de derechos (ENTITLEMENT_SIGNING_KEY)</li>
            <li>{{ $googleOk ? '✅' : '⚠️' }} Google Play (GOOGLE_SERVICE_ACCOUNT_JSON)</li>
            <li>{{ $rtdnOk ? '✅' : '⚠️' }} Notificaciones de Google (GOOGLE_RTDN_TOKEN)</li>
            <li>{{ $appleOk ? '✅' : '⚠️' }} App Store (APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY · {{ config('mininoches.apple.bundle_id') }}, {{ config('mininoches.apple.environment') }})</li>
        </ul>
        <h3 class="font-semibold mt-4 mb-2 text-sm">Packs importados</h3>
        <ul class="text-sm space-y-1">
            @forelse ($packs as $pack)
                <li>{{ $pack->name }} <span class="text-slate-500">({{ $pack->id }} {{ $pack->version }}, {{ $pack->imported_at?->format('d/m/Y H:i') }})</span></li>
            @empty
                <li class="text-slate-500">Ninguno. Ejecute <code>php artisan mininoches:import-packs</code>.</li>
            @endforelse
        </ul>
    </section>
</div>
@endsection
