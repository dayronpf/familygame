@extends('layouts.admin')
@section('title', 'Códigos')
@section('content')
<x-page-header title="Códigos de regalo" subtitle="Códigos gratuitos que abren todos los cuentos por unos días: regalos, promociones, escuelas o los revisores de las tiendas. Se regalan, nunca se venden: lo que se cobra va por Google Play (su política lo exige). Solo funcionan en Android. Cada teléfono puede usar un mismo código una sola vez, y los días se suman a lo que ya tenga.">
    <x-slot:actions>
        <x-btn variant="primary" icon="plus" type="button" onclick="document.getElementById('new-code').toggleAttribute('open'); document.querySelector('#new-code input')?.focus()">Crear códigos</x-btn>
    </x-slot:actions>
</x-page-header>

<details id="new-code" class="mb-6 group" @if ($errors->any()) open @endif>
    <summary class="hidden"></summary>
    <x-card title="Crear códigos">
        <form method="post" action="{{ route('admin.codes.store') }}" class="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
            @csrf
            <x-field label="Código" name="code" hint="Déjalo vacío para crear códigos al azar (MINI-XXXX-XXXX)." class="lg:col-span-2">
                <input name="code" value="{{ old('code') }}" placeholder="ESCUELA-2026" class="input uppercase font-mono">
            </x-field>
            <x-field label="Cuántos (si son al azar)" name="quantity">
                <input type="number" name="quantity" min="1" max="500" value="{{ old('quantity', 1) }}" class="input">
            </x-field>
            <x-field label="Días de acceso" name="days" hint="Cuánto dura lo que abre.">
                <input type="number" name="days" min="1" max="3650" value="{{ old('days', 30) }}" class="input" required>
            </x-field>
            <x-field label="Usos de cada código" name="max_uses" hint="Cuántos teléfonos pueden usarlo.">
                <input type="number" name="max_uses" min="1" value="{{ old('max_uses', 1) }}" class="input" required>
            </x-field>
            <x-field label="Se puede canjear hasta" name="expires_at" hint="Opcional.">
                <input type="date" name="expires_at" value="{{ old('expires_at') }}" class="input">
            </x-field>
            <x-field label="Para quién es" name="note" class="lg:col-span-2">
                <input name="note" value="{{ old('note') }}" maxlength="255" placeholder="Escuela San José, 3.er grado" class="input">
            </x-field>
            <div class="sm:col-span-2 lg:col-span-4 flex justify-end gap-2">
                <x-btn variant="ghost" type="button" onclick="document.getElementById('new-code').removeAttribute('open')">Cancelar</x-btn>
                <x-btn variant="primary" icon="plus">Crear</x-btn>
            </div>
        </form>
    </x-card>
</details>

<form method="get" class="flex flex-wrap items-center gap-2 mb-4">
    <div class="relative flex-1 min-w-[16rem]">
        <x-icon name="search" class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input name="q" value="{{ $q }}" placeholder="Buscar código o nota…" class="input pl-9">
    </div>
    <select name="estado" class="input w-auto" onchange="this.form.submit()">
        <option value="">Todos</option>
        @foreach (['activos' => 'Se pueden usar', 'agotados' => 'Agotados', 'caducados' => 'Caducados', 'desactivados' => 'Desactivados'] as $v => $l)
            <option value="{{ $v }}" @selected($estado === $v)>{{ $l }}</option>
        @endforeach
    </select>
    <x-btn variant="secondary" icon="search">Buscar</x-btn>
    @if ($q !== '' || $estado !== '')<x-btn variant="ghost" icon="x" :href="route('admin.codes.index')">Limpiar</x-btn>@endif
    <span class="ml-auto text-sm text-slate-500">{{ $totals['all'] }} códigos · {{ $totals['redeemed'] }} canjes</span>
</form>

<x-card :padding="false">
    <div class="overflow-x-auto">
    <table class="table-base">
        <thead><tr><th>Código</th><th>Para quién</th><th class="text-right">Días</th><th>Usos</th><th>Canjear hasta</th><th>Estado</th><th class="text-right">Acciones</th></tr></thead>
        <tbody>
        @forelse ($codes as $c)
            @php
                $used = $c->uses_count >= $c->max_uses;
                $expired = $c->expires_at && $c->expires_at->isPast();
            @endphp
            <tr>
                <td class="whitespace-nowrap">
                    <span class="font-mono font-medium">{{ $c->code }}</span>
                    <button type="button" data-copy="{{ $c->code }}" class="ml-1 text-slate-400 hover:text-brand-700 align-middle" title="Copiar"><x-icon name="copy" class="w-4 h-4" /></button>
                    <div class="text-xs text-slate-400">creado {{ $c->created_at->format('d/m/Y') }}</div>
                </td>
                <td class="max-w-xs">{{ $c->note ?: '—' }}</td>
                <td class="text-right tabular-nums">{{ $c->days }}</td>
                <td class="min-w-[8rem]">
                    <div class="flex items-center gap-2"><div class="flex-1 bg-slate-100 rounded-full h-1.5"><div class="h-1.5 rounded-full {{ $used ? 'bg-slate-400' : 'bg-brand-500' }}" style="width: {{ min(100, round($c->uses_count * 100 / max(1, $c->max_uses))) }}%"></div></div>
                        <span class="text-xs tabular-nums text-slate-600">{{ $c->uses_count }}/{{ $c->max_uses }}</span></div>
                </td>
                <td class="whitespace-nowrap">{{ $c->expires_at?->format('d/m/Y') ?? 'Sin límite' }}</td>
                <td>
                    @if (! $c->active)<x-badge dot>Desactivado</x-badge>
                    @elseif ($used)<x-badge color="slate" dot>Agotado</x-badge>
                    @elseif ($expired)<x-badge color="amber" dot>Caducado</x-badge>
                    @else<x-badge color="green" dot>Se puede usar</x-badge>@endif
                </td>
                <td class="text-right">
                    <form method="post" action="{{ route('admin.codes.toggle', $c) }}">@csrf
                        @if ($c->active)
                            <x-btn variant="danger-ghost" size="sm" data-confirm="Nadie más podrá canjearlo. Quienes ya lo usaron conservan sus días." data-confirm-title="Desactivar {{ $c->code }}" data-confirm-ok="Desactivar">Desactivar</x-btn>
                        @else
                            <x-btn variant="ghost" size="sm">Activar</x-btn>
                        @endif
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="7"><x-empty title="No hay códigos" icon="ticket">@if ($q || $estado) Prueba con otra búsqueda. @else Crea el primero con «Crear códigos». @endif</x-empty></td></tr>
        @endforelse
        </tbody>
    </table>
    </div>
</x-card>
<div class="mt-4 flex flex-wrap items-center gap-4"><div class="flex-1">{{ $codes->links() }}</div><x-per-page :value="$perPage" /></div>
@endsection
