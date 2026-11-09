@extends('layouts.admin')
@section('title', 'Auditoría')
@section('content')
<h1 class="text-2xl font-semibold mb-4">Auditoría</h1>
<div class="bg-white rounded-xl border border-slate-200 overflow-x-auto mb-2">
<table class="w-full text-sm">
    <thead class="bg-slate-100 text-left text-slate-600"><tr><th class="p-2">Fecha (UTC)</th><th class="p-2">Quién</th><th class="p-2">Acción</th><th class="p-2">Sobre</th><th class="p-2">Detalles</th></tr></thead>
    <tbody>
    @forelse ($logs as $log)
        <tr class="border-t border-slate-100 align-top">
            <td class="p-2 whitespace-nowrap">{{ $log->created_at->format('d/m/Y H:i:s') }}</td>
            <td class="p-2">{{ $log->user?->email ?? '—' }}</td>
            <td class="p-2 font-mono text-xs">{{ $log->action }}</td>
            <td class="p-2 text-xs">{{ $log->subject_type }} {{ $log->subject_id }}</td>
            <td class="p-2 text-xs font-mono break-all">{{ $log->details ? json_encode($log->details, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : '' }}</td>
        </tr>
    @empty
        <tr><td colspan="5" class="p-6 text-center text-slate-500">Sin registros.</td></tr>
    @endforelse
    </tbody>
</table>
</div>
{{ $logs->links() }}
@endsection
