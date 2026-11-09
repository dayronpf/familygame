@extends('layouts.admin')
@section('title', 'Valoraciones')
@section('content')
<h1 class="text-2xl font-semibold mb-1">Valoraciones</h1>
<p class="text-sm text-slate-600 mb-4">{{ $total }} valoraciones anónimas @if ($avg) · promedio {{ number_format($avg, 2, ',', '') }} @endif. Sin instalación, IP ni hora: solo nota, motivo, receta del cuento y día.</p>

<div class="grid lg:grid-cols-3 gap-6 mb-6">
    <section class="bg-white rounded-xl border border-slate-200 p-4">
        <h2 class="font-semibold mb-2">Por pack</h2>
        <table class="w-full text-sm">
            <thead class="text-left text-slate-500"><tr><th>Pack</th><th>N</th><th>Prom.</th><th>≤ 3</th></tr></thead>
            <tbody>
            @forelse ($byPack as $r)
                <tr class="border-t"><td class="py-1">{{ $r->pack_id }}</td><td>{{ $r->n }}</td><td>{{ number_format($r->avg, 2, ',', '') }}</td><td>{{ $r->low }}</td></tr>
            @empty
                <tr><td colspan="4" class="py-2 text-slate-500">Sin datos.</td></tr>
            @endforelse
            </tbody>
        </table>
    </section>
    <section class="bg-white rounded-xl border border-slate-200 p-4 lg:col-span-2">
        <h2 class="font-semibold mb-2">Motivos de las notas bajas</h2>
        @php($maxReason = max(1, max($reasons)))
        @foreach ($reasons as $code => $c)
            <div class="flex items-center gap-2 text-sm mb-1">
                <span class="w-48">{{ \App\Models\StoryRating::REASONS[$code] ?? $code }}</span>
                <div class="flex-1 bg-slate-100 rounded h-2"><div class="bg-rose-400 h-2 rounded" style="width: {{ round($c * 100 / $maxReason) }}%"></div></div>
                <span class="w-10 text-right">{{ $c }}</span>
            </div>
        @endforeach
    </section>
</div>

<div class="flex items-center gap-3 mb-2">
    <h2 class="font-semibold">Por cuento (peor valorados primero)</h2>
    <form method="get" class="text-sm ml-auto">Mínimo de valoraciones <input type="number" name="min" min="1" value="{{ $minCount }}" class="border rounded px-2 py-0.5 w-20"> <button class="underline">Aplicar</button></form>
</div>
<div class="bg-white rounded-xl border border-slate-200 overflow-x-auto">
<table class="w-full text-sm">
    <thead class="bg-slate-100 text-left text-slate-600"><tr><th class="p-2">Cuento</th><th class="p-2">N</th><th class="p-2">Promedio</th><th class="p-2">Notas ≤ 3</th><th class="p-2">Motivos</th></tr></thead>
    <tbody>
    @forelse ($byPremise as $r)
        @php($ref = $r->pack_id.':'.$r->premise_id)
        @php($premise = $premises[$ref] ?? null)
        <tr class="border-t border-slate-100">
            <td class="p-2">@if ($premise)<a class="text-indigo-700 hover:underline" href="{{ route('admin.stories.show', $premise->id) }}">{{ $premise->title }}</a>@else {{ $ref }} @endif <div class="text-xs text-slate-400">{{ $ref }}</div></td>
            <td class="p-2">{{ $r->n }}</td>
            <td class="p-2">{{ number_format($r->avg, 2, ',', '') }}</td>
            <td class="p-2">{{ $r->low }}</td>
            <td class="p-2 text-xs">
                @foreach ($reasonsByPremise[$ref] ?? [] as $code => $c) {{ \App\Models\StoryRating::REASONS[$code] ?? $code }}: {{ $c }}@if (! $loop->last) · @endif @endforeach
            </td>
        </tr>
    @empty
        <tr><td colspan="5" class="p-6 text-center text-slate-500">Sin valoraciones todavía.</td></tr>
    @endforelse
    </tbody>
</table>
</div>
@endsection
