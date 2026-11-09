@extends('layouts.admin')
@section('title', 'Códigos')
@section('content')
<h1 class="text-2xl font-semibold mb-4">Códigos de canje</h1>
<form method="post" action="{{ route('admin.codes.store') }}" class="bg-white rounded-xl border border-slate-200 p-4 mb-6 grid sm:grid-cols-3 lg:grid-cols-7 gap-3 text-sm items-end">
    @csrf
    <label class="lg:col-span-2">Código (vacío = aleatorio MINI-XXXX-XXXX)<br>
        <input name="code" value="{{ old('code') }}" placeholder="p. ej. ESCUELA-2026" class="border rounded px-2 py-1 w-full uppercase"></label>
    <label>Días<br><input type="number" name="days" min="1" value="{{ old('days', 30) }}" class="border rounded px-2 py-1 w-full" required></label>
    <label>Usos máximos<br><input type="number" name="max_uses" min="1" value="{{ old('max_uses', 1) }}" class="border rounded px-2 py-1 w-full" required></label>
    <label>Caduca (opcional)<br><input type="date" name="expires_at" value="{{ old('expires_at') }}" class="border rounded px-2 py-1 w-full"></label>
    <label>Cantidad (aleatorios)<br><input type="number" name="quantity" min="1" max="500" value="{{ old('quantity', 1) }}" class="border rounded px-2 py-1 w-full"></label>
    <label class="sm:col-span-2 lg:col-span-6">Nota (para quién es)<br><input name="note" value="{{ old('note') }}" class="border rounded px-2 py-1 w-full"></label>
    <button class="rounded-md bg-indigo-700 text-white px-3 py-1.5">Crear</button>
</form>
<p class="text-xs text-slate-500 mb-3">Cada teléfono puede canjear un mismo código una sola vez. Los días se suman a lo que ya tenga (suscripción o código anterior).</p>
<div class="bg-white rounded-xl border border-slate-200 overflow-x-auto mb-2">
<table class="w-full text-sm">
    <thead class="bg-slate-100 text-left text-slate-600"><tr>
        <th class="p-2">Código</th><th class="p-2">Días</th><th class="p-2">Usos</th><th class="p-2">Caduca</th><th class="p-2">Nota</th><th class="p-2">Creado</th><th class="p-2">Estado</th></tr></thead>
    <tbody>
    @forelse ($codes as $c)
        <tr class="border-t border-slate-100">
            <td class="p-2 font-mono">{{ $c->code }}</td>
            <td class="p-2">{{ $c->days }}</td>
            <td class="p-2">{{ $c->uses_count }} / {{ $c->max_uses }}</td>
            <td class="p-2">{{ $c->expires_at?->format('d/m/Y') ?? '—' }}</td>
            <td class="p-2">{{ $c->note }}</td>
            <td class="p-2">{{ $c->created_at->format('d/m/Y') }}</td>
            <td class="p-2">
                <form method="post" action="{{ route('admin.codes.toggle', $c) }}">@csrf
                    <button class="rounded-full px-2 py-0.5 text-xs font-medium {{ $c->active ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-200 text-slate-600' }}">
                        {{ $c->active ? 'Activo · desactivar' : 'Inactivo · activar' }}</button>
                </form>
            </td>
        </tr>
    @empty
        <tr><td colspan="7" class="p-6 text-center text-slate-500">Aún no hay códigos.</td></tr>
    @endforelse
    </tbody>
</table>
</div>
{{ $codes->links() }}
@endsection
