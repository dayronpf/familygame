@extends('layouts.admin')
@section('title', 'Auditoría')
@section('content')
<x-page-header title="Auditoría" subtitle="Todo lo que se hizo en el panel, quién y cuándo (hora UTC)." />

<form method="get" class="flex flex-wrap items-end gap-2 mb-4">
    <div class="relative flex-1 min-w-[14rem]">
        <x-icon name="search" class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input name="q" value="{{ $q }}" placeholder="Buscar en los detalles (p. ej. un id de cuento o un código)…" class="input pl-9">
    </div>
    <select name="tipo" class="input w-auto" onchange="this.form.submit()">
        <option value="">Todo</option>
        @foreach ($types as $v => $l)<option value="{{ $v }}" @selected($tipo === $v)>{{ $l }}</option>@endforeach
    </select>
    <label class="text-xs text-slate-500">Desde<input type="date" name="desde" value="{{ $desde }}" class="input w-auto"></label>
    <label class="text-xs text-slate-500">Hasta<input type="date" name="hasta" value="{{ $hasta }}" class="input w-auto"></label>
    <x-btn variant="secondary" icon="search">Filtrar</x-btn>
    @if ($q || $tipo || $desde || $hasta)<x-btn variant="ghost" icon="x" :href="route('admin.audit.index')">Limpiar</x-btn>@endif
</form>

<x-card :padding="false">
    <div class="overflow-x-auto">
    <table class="table-base">
        <thead><tr><th>Fecha</th><th>Quién</th><th>Qué</th><th>Sobre</th><th>Detalles</th></tr></thead>
        <tbody>
        @forelse ($logs as $log)
            <tr class="align-top">
                <td class="whitespace-nowrap text-slate-600">{{ $log->created_at->format('d/m/Y H:i') }}</td>
                <td class="whitespace-nowrap">{{ $log->user?->email ?? 'Sistema' }}</td>
                <td class="whitespace-nowrap"><span class="font-medium">{{ \App\Models\AuditLog::label($log->action) }}</span><div class="text-[11px] text-slate-400 font-mono">{{ $log->action }}</div></td>
                <td class="whitespace-nowrap">
                    @if ($log->subject_type === 'Premise' && $log->subject_id)
                        <a class="text-brand-700 hover:underline" href="{{ route('admin.stories.show', $log->subject_id) }}">{{ $log->details['ref'] ?? 'Cuento '.$log->subject_id }}</a>
                    @else
                        {{ $log->details['ref'] ?? trim($log->subject_type.' '.$log->subject_id) ?: '—' }}
                    @endif
                </td>
                <td class="text-xs">
                    @if ($log->details)
                        <details><summary class="cursor-pointer text-slate-500 hover:text-slate-800">Ver</summary>
                            <pre class="mt-1 whitespace-pre-wrap break-all font-mono text-[11px] text-slate-700 max-w-xl">{{ json_encode($log->details, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) }}</pre></details>
                    @endif
                </td>
            </tr>
        @empty
            <tr><td colspan="5"><x-empty title="Sin registros" icon="clipboard" /></td></tr>
        @endforelse
        </tbody>
    </table>
    </div>
</x-card>
<div class="mt-4">{{ $logs->links() }}</div>
@endsection
