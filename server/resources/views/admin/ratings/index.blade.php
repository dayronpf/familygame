@extends('layouts.admin')
@section('title', 'Valoraciones')
@section('content')
<x-page-header title="Valoraciones" subtitle="Lo que opinan las familias de cada cuento. Son anónimas: solo la nota, el motivo y el día; sin teléfono, sin IP y sin hora." />

<div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
    <x-stat label="Valoraciones" :value="$total" icon="star" tone="amber" />
    <x-stat label="Promedio" :value="$avg ? number_format($avg, 1, ',', '') : '—'" hint="de 5" icon="star" tone="amber" />
</div>

<div class="grid lg:grid-cols-3 gap-6 mb-6">
    <x-card title="Por mundo">
        <table class="table-base">
            <thead><tr><th>Mundo</th><th class="text-right">Votos</th><th class="text-right">Promedio</th><th class="text-right">≤ 3</th></tr></thead>
            <tbody>
            @forelse ($byPack as $r)
                <tr><td>{{ $r->pack_id }}</td><td class="text-right tabular-nums">{{ $r->n }}</td><td class="text-right tabular-nums">{{ number_format($r->avg, 1, ',', '') }}</td><td class="text-right tabular-nums">{{ $r->low }}</td></tr>
            @empty
                <tr><td colspan="4" class="text-slate-500">Sin datos.</td></tr>
            @endforelse
            </tbody>
        </table>
    </x-card>
    <x-card title="Por qué no gustan" subtitle="Motivos que marcan las familias con notas de 3 o menos." class="lg:col-span-2">
        @php $maxReason = max(1, max($reasons ?: [0])); @endphp
        @foreach ($reasons as $code => $c)
            <div class="flex items-center gap-3 text-sm mb-2">
                <span class="w-48 text-slate-700">{{ \App\Models\StoryRating::REASONS[$code] ?? $code }}</span>
                <div class="flex-1 bg-slate-100 rounded-full h-2"><div class="bg-rose-400 h-2 rounded-full" style="width: {{ round($c * 100 / $maxReason) }}%"></div></div>
                <span class="w-10 text-right tabular-nums">{{ $c }}</span>
            </div>
        @endforeach
    </x-card>
</div>

<x-card title="Por cuento" :padding="false">
    <x-slot:actions>
        <form method="get" class="flex flex-wrap items-center gap-2 text-sm">
            <input type="hidden" name="orden" value="{{ $sort }}"><input type="hidden" name="dir" value="{{ $dir }}">
            <select name="pack" class="input w-auto py-1" onchange="this.form.submit()">
                <option value="">Todos los mundos</option>
                @foreach ($byPack as $r)<option value="{{ $r->pack_id }}" @selected($packFilter === $r->pack_id)>{{ $r->pack_id }}</option>@endforeach
            </select>
            <label class="inline-flex items-center gap-2 text-slate-600">Con al menos
                <input type="number" name="min" min="1" value="{{ $minCount }}" class="input w-16 py-1" onchange="this.form.submit()"> votos</label>
        </form>
    </x-slot:actions>
    <div class="overflow-x-auto">
    <table class="table-base">
        <thead><tr>
            <th>Cuento</th>
            <x-sort column="n" label="Votos" :sort="$sort" :dir="$dir" class="text-right" />
            <x-sort column="avg" label="Promedio" :sort="$sort" :dir="$dir" />
            <x-sort column="low" label="Notas ≤ 3" :sort="$sort" :dir="$dir" class="text-right" />
            <th>Motivos</th>
        </tr></thead>
        <tbody>
        @forelse ($byPremise as $r)
            @php
                $ref = $r->pack_id.':'.$r->premise_id;
                $premise = $premises[$ref] ?? null;
            @endphp
            <tr>
                <td>@if ($premise)<a class="font-medium text-slate-900 hover:text-brand-700" href="{{ route('admin.stories.show', ['premise' => $premise->id, 'vista' => 'valoraciones']) }}">{{ $premise->title }}</a>@else {{ $ref }} @endif
                    <div class="text-xs text-slate-400 font-mono">{{ $ref }}</div></td>
                <td class="text-right tabular-nums">{{ $r->n }}</td>
                <td class="whitespace-nowrap"><span class="inline-flex items-center gap-1"><x-icon name="star" class="w-4 h-4 text-amber-400" /><b>{{ number_format($r->avg, 1, ',', '') }}</b></span></td>
                <td class="text-right tabular-nums">{{ $r->low }}</td>
                <td class="text-xs text-slate-600">
                    @foreach ($reasonsByPremise[$ref] ?? [] as $code => $c){{ \App\Models\StoryRating::REASONS[$code] ?? $code }} ({{ $c }})@if (! $loop->last) · @endif @endforeach
                </td>
            </tr>
        @empty
            <tr><td colspan="5"><x-empty title="Sin valoraciones todavía." icon="star">Cuando las familias valoren cuentos, verás aquí cuáles gustan más y cuáles menos.</x-empty></td></tr>
        @endforelse
        </tbody>
    </table>
    </div>
</x-card>
<div class="mt-4">{{ $byPremise->links() }}</div>
@endsection
