@extends('layouts.admin')
@section('title', 'Cuentos')
@section('content')
<div class="flex flex-wrap items-center gap-3 mb-4">
    <h1 class="text-2xl font-semibold">Cuentos</h1>
    <span class="text-slate-500 text-sm">{{ $premises->count() }} en la lista @if ($removed) · {{ $removed }} retirados de los packs @endif</span>
    <form method="post" action="{{ route('admin.stories.import') }}" class="ml-auto">
        @csrf
        <button class="rounded-md border border-indigo-300 text-indigo-800 px-3 py-1.5 text-sm hover:bg-indigo-50"
                title="Lee content/packs/*/pack.json y actualiza el texto sin tocar la revisión">Importar packs de nuevo</button>
    </form>
</div>
<p class="text-sm text-slate-600 mb-4">Los cuentos <b>pendientes</b> siguen saliendo en la app; solo los <b>rechazados</b> se ocultan. Cada cambio publica una versión nueva del catálogo.</p>

<form method="get" class="bg-white rounded-xl border border-slate-200 p-3 mb-4 flex flex-wrap gap-2 items-end text-sm">
    <label>Pack<br>
        <select name="pack" class="border rounded px-2 py-1">
            <option value="">Todos</option>
            @foreach ($packs as $p) <option value="{{ $p->id }}" @selected(($filters['pack'] ?? '') === $p->id)>{{ $p->name }}</option> @endforeach
        </select>
    </label>
    <label>Edad<br>
        <select name="age" class="border rounded px-2 py-1">
            <option value="">Todas</option>
            @foreach ($ages as $a) <option value="{{ $a }}" @selected(($filters['age'] ?? '') === $a)>{{ $a }} años</option> @endforeach
        </select>
    </label>
    <label>Enseñanza<br>
        <select name="moral" class="border rounded px-2 py-1">
            <option value="">Todas</option>
            @foreach ($morals as $m) <option value="{{ $m['id'] }}" @selected(($filters['moral'] ?? '') === $m['id'])>{{ $m['name'] }}</option> @endforeach
        </select>
    </label>
    <label>Estado<br>
        <select name="status" class="border rounded px-2 py-1">
            <option value="">Todos</option>
            @foreach (\App\Models\Premise::STATUSES as $s) <option value="{{ $s }}" @selected(($filters['status'] ?? '') === $s)>{{ ucfirst($s) }}</option> @endforeach
        </select>
    </label>
    <label>Gratis<br>
        <select name="free" class="border rounded px-2 py-1">
            <option value="">Todos</option>
            <option value="1" @selected(($filters['free'] ?? '') === '1')>Solo gratis</option>
            <option value="0" @selected(($filters['free'] ?? '') === '0')>Solo de pago</option>
        </select>
    </label>
    <label>Buscar<br><input name="q" value="{{ $filters['q'] ?? '' }}" placeholder="título o id" class="border rounded px-2 py-1"></label>
    <button class="rounded-md bg-indigo-700 text-white px-3 py-1.5">Filtrar</button>
    <a href="{{ route('admin.stories.index') }}" class="text-slate-500 underline px-2 py-1.5">Limpiar</a>
</form>

<div class="bg-white rounded-xl border border-slate-200 overflow-x-auto">
<table class="w-full text-sm">
    <thead class="bg-slate-100 text-left text-slate-600">
        <tr><th class="p-2">Cuento</th><th class="p-2">Pack</th><th class="p-2">Edad</th><th class="p-2">Enseñanza</th><th class="p-2">Escenas</th><th class="p-2">Valoración</th><th class="p-2">Estado</th><th class="p-2">Gratis</th></tr>
    </thead>
    <tbody>
    @forelse ($premises as $p)
        @php($r = $ratings[$p->ref] ?? null)
        <tr class="border-t border-slate-100 hover:bg-slate-50">
            <td class="p-2"><a href="{{ route('admin.stories.show', $p) }}" class="text-indigo-700 font-medium hover:underline">{{ $p->title }}</a><div class="text-xs text-slate-400">{{ $p->ref }}</div></td>
            <td class="p-2">{{ $p->pack?->name }}</td>
            <td class="p-2">{{ implode(', ', $p->ages ?? []) }}</td>
            <td class="p-2">{{ $p->pack?->moralName($p->value) }}</td>
            <td class="p-2">{{ $p->beat_count }} <span class="text-slate-400">/ {{ $p->variant_count }} var.</span></td>
            <td class="p-2">@if ($r) {{ number_format($r->avg, 1, ',', '') }} <span class="text-slate-400">({{ $r->n }})</span> @else <span class="text-slate-300">—</span> @endif</td>
            <td class="p-2">@include('admin.stories._status', ['status' => $p->review_status])</td>
            <td class="p-2">
                <form method="post" action="{{ route('admin.stories.free', $p) }}">@csrf
                    <button class="rounded-full px-2 py-0.5 text-xs font-medium {{ $p->is_free ? 'bg-sky-100 text-sky-800' : 'bg-slate-100 text-slate-500' }}"
                            title="Cambiar">{{ $p->is_free ? 'Gratis' : 'De pago' }}</button>
                </form>
            </td>
        </tr>
    @empty
        <tr><td colspan="8" class="p-6 text-center text-slate-500">No hay cuentos con esos filtros. ¿Importó los packs?</td></tr>
    @endforelse
    </tbody>
</table>
</div>
@endsection
