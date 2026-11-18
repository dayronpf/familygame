@extends('layouts.admin')
@section('title', 'Cuentos')
@section('content')
<x-page-header title="Cuentos" subtitle="Busca, revisa y edita los cuentos. Ocultar y «Gratis» cambian la app al momento; los textos y los cuentos nuevos se publican desde la cola.">
    <x-slot:actions>
        @if ($queue['drafts'] + $queue['failed'] > 0)
            <form method="post" action="{{ route('admin.stories.publish_all') }}">@csrf
                <x-btn variant="secondary" icon="send" data-confirm-tone="primary" data-confirm-title="Publicar todos los cambios"
                    data-confirm="Se publicarán {{ $queue['drafts'] + $queue['failed'] }} cuentos con cambios. La app los recibirá cuando termine la publicación."
                    data-confirm-ok="Publicar">Publicar cambios ({{ $queue['drafts'] + $queue['failed'] }})</x-btn>
            </form>
        @endif
        <x-btn variant="primary" icon="plus" :href="route('admin.stories.create')">Nuevo cuento</x-btn>
    </x-slot:actions>
</x-page-header>

@if ($queue['queued'] > 0 || $queue['failed'] > 0)
    <div class="mb-4 rounded-xl border px-4 py-3 text-sm flex flex-wrap items-center gap-2 {{ $queue['failed'] ? 'border-rose-200 bg-rose-50 text-rose-800' : 'border-sky-200 bg-sky-50 text-sky-800' }}">
        <x-icon :name="$queue['failed'] ? 'alert' : 'refresh'" class="w-4 h-4" />
        @if ($queue['queued'])<span><b>{{ $queue['queued'] }}</b> {{ $queue['queued'] === 1 ? 'cuento está' : 'cuentos están' }} en cola para publicar.</span>@endif
        @if ($queue['failed'])<span><b>{{ $queue['failed'] }}</b> no se {{ $queue['failed'] === 1 ? 'pudo' : 'pudieron' }} publicar: revisa el error en la ficha.</span>@endif
        <a href="{{ route('admin.stories.index', ['vista' => 'cambios']) }}" class="ml-auto underline">Ver</a>
    </div>
@endif

{{-- Pestañas --}}
<div class="border-b border-slate-200 mb-4 overflow-x-auto">
    <nav class="flex gap-6">
        @foreach ($tabs as $key => $label)
            <a href="{{ request()->fullUrlWithQuery(['vista' => $key === 'todos' ? null : $key, 'page' => null]) }}" class="tab {{ $tab === $key ? 'active' : '' }}">
                {{ $label }} <span class="rounded-full px-2 py-0.5 text-xs {{ $tab === $key ? 'bg-brand-100 text-brand-700' : 'bg-slate-100 text-slate-600' }}">{{ $counts[$key] }}</span>
            </a>
        @endforeach
    </nav>
</div>

{{-- Búsqueda y filtros --}}
<form method="get" class="flex flex-wrap items-center gap-2 mb-4">
    @if ($tab !== 'todos')<input type="hidden" name="vista" value="{{ $tab }}">@endif
    <input type="hidden" name="orden" value="{{ $sort }}"><input type="hidden" name="dir" value="{{ $dir }}">
    <div class="relative w-full">
        <x-icon name="search" class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input name="q" value="{{ $filters['q'] }}" placeholder="Buscar por título, id o texto del cuento…" class="input pl-9" autofocus>
    </div>
    <select name="pack" class="input w-auto" onchange="this.form.submit()">
        <option value="">Todos los mundos</option>
        @foreach ($packs as $p)<option value="{{ $p->id }}" @selected($filters['pack'] === $p->id)>{{ $p->name }}</option>@endforeach
    </select>
    <select name="edad" class="input w-auto" onchange="this.form.submit()">
        <option value="">Todas las edades</option>
        @foreach ($ages as $a)<option value="{{ $a }}" @selected($filters['edad'] === $a)>{{ $a }} años</option>@endforeach
    </select>
    <select name="ensenanza" class="input w-auto" onchange="this.form.submit()">
        <option value="">Todas las enseñanzas</option>
        @foreach ($morals as $m)<option value="{{ $m['id'] }}" @selected($filters['ensenanza'] === $m['id'])>{{ $m['name'] }}</option>@endforeach
    </select>
    <select name="gratis" class="input w-auto" onchange="this.form.submit()">
        <option value="">Gratis y de pago</option>
        <option value="1" @selected($filters['gratis'] === '1')>Solo gratis</option>
        <option value="0" @selected($filters['gratis'] === '0')>Solo de pago</option>
    </select>
    <x-btn variant="secondary" icon="search">Buscar</x-btn>
    @if (array_filter($filters))
        <x-btn variant="ghost" :href="route('admin.stories.index', array_filter(['vista' => $tab === 'todos' ? null : $tab]))" icon="x">Limpiar</x-btn>
    @endif
</form>

<form method="post" action="{{ route('admin.stories.bulk') }}" id="bulk-form">@csrf
{{-- Barra de acciones en lote --}}
<div data-bulk class="hidden sticky top-2 z-10 mb-3 flex flex-wrap items-center gap-2 rounded-xl bg-night-950 text-white px-4 py-2.5 shadow-lg">
    <span class="text-sm"><b data-bulk-count>0</b> seleccionados</span>
    <span class="mx-1 h-5 w-px bg-white/20"></span>
    @foreach (['aprobar' => 'Aprobar', 'mostrar' => 'Mostrar en la app', 'gratis' => 'Hacer gratis', 'pago' => 'Hacer de pago', 'publicar' => 'Publicar cambios'] as $action => $label)
        <button name="accion" value="{{ $action }}" class="rounded-lg px-2.5 py-1 text-sm hover:bg-white/10">{{ $label }}</button>
    @endforeach
    <button name="accion" value="ocultar" class="rounded-lg px-2.5 py-1 text-sm text-rose-300 hover:bg-white/10"
        data-confirm="Los cuentos seleccionados dejarán de salir en la app. Puedes volver a mostrarlos cuando quieras." data-confirm-title="Ocultar de la app" data-confirm-ok="Ocultar">Ocultar</button>
</div>

<x-card :padding="false">
    <div class="overflow-x-auto">
    <table class="table-base">
        <thead><tr>
            <th class="w-10"><input type="checkbox" data-check-all class="rounded border-slate-300 text-brand-600" aria-label="Seleccionar todos"></th>
            <x-sort column="titulo" label="Cuento" :sort="$sort" :dir="$dir" />
            <x-sort column="pack" label="Mundo" :sort="$sort" :dir="$dir" />
            <x-sort column="edad" label="Edad" :sort="$sort" :dir="$dir" />
            <x-sort column="escenas" label="Escenas" :sort="$sort" :dir="$dir" class="text-right" />
            <x-sort column="valoracion" label="Valoración" :sort="$sort" :dir="$dir" />
            <th>Estado</th>
            <th class="w-24"><span class="sr-only">Acciones</span></th>
        </tr></thead>
        <tbody>
        @forelse ($premises as $p)
            <tr>
                <td><input type="checkbox" name="ids[]" value="{{ $p->id }}" data-row-check class="rounded border-slate-300 text-brand-600" aria-label="Seleccionar {{ $p->title }}"></td>
                <td class="max-w-xs">
                    <a href="{{ route('admin.stories.show', $p) }}" class="font-medium text-slate-900 hover:text-brand-700">{{ $p->draft['title'] ?? $p->title }}</a>
                    <div class="text-xs text-slate-500">{{ $p->pack?->moralName($p->value) }} · <span class="font-mono text-slate-400">{{ $p->ref }}</span></div>
                </td>
                <td class="whitespace-nowrap">{{ $p->pack?->name }}</td>
                <td class="whitespace-nowrap">{{ implode(', ', $p->ages ?? []) }}</td>
                <td class="text-right tabular-nums">{{ $p->beat_count }}</td>
                <td class="whitespace-nowrap">
                    @if ($p->rating_n)<span class="inline-flex items-center gap-1"><x-icon name="star" class="w-4 h-4 text-amber-400" /><b>{{ number_format($p->rating_avg, 1, ',', '') }}</b> <span class="text-slate-400 text-xs">({{ $p->rating_n }})</span></span>
                    @else<span class="text-slate-300">—</span>@endif
                </td>
                <td><div class="flex flex-wrap gap-1">@include('admin.stories._status', ['premise' => $p, 'compact' => true])
                    @if ($p->is_free)<x-badge color="blue">Gratis</x-badge>@endif</div></td>
                <td class="text-right whitespace-nowrap">
                    <a href="{{ route('admin.stories.show', $p) }}" class="inline-flex p-1.5 rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900" title="Ver"><x-icon name="eye" class="w-4 h-4" /></a>
                    <a href="{{ route('admin.stories.edit', $p) }}" class="inline-flex p-1.5 rounded-md text-slate-500 hover:bg-slate-100 hover:text-brand-700" title="Editar"><x-icon name="pencil" class="w-4 h-4" /></a>
                </td>
            </tr>
        @empty
            <tr><td colspan="8">
                <x-empty title="No hay cuentos con estos filtros" icon="book">Prueba con otra búsqueda o <a class="text-brand-700 underline" href="{{ route('admin.stories.index') }}">quita los filtros</a>.</x-empty>
            </td></tr>
        @endforelse
        </tbody>
    </table>
    </div>
</x-card>
</form>

<div class="mt-4 flex flex-wrap items-center gap-4">
    <div class="flex-1">{{ $premises->links() }}</div>
    <x-per-page :value="$perPage" />
</div>

<details class="mt-8 text-sm text-slate-500">
    <summary class="cursor-pointer hover:text-slate-700">Opciones avanzadas</summary>
    <div class="mt-3 flex flex-wrap items-center gap-3">
        <form method="post" action="{{ route('admin.stories.import') }}">@csrf
            <x-btn variant="secondary" size="sm" icon="refresh" data-confirm-tone="primary" data-confirm-title="Volver a leer los packs"
                data-confirm="Lee otra vez content/packs del servidor y actualiza el texto publicado. No toca la revisión, «Gratis» ni los borradores." data-confirm-ok="Leer">Volver a leer los packs</x-btn>
        </form>
        <span>Normalmente no hace falta: cada publicación lo hace sola.</span>
    </div>
</details>
@endsection
