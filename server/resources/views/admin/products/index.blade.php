@extends('layouts.admin')
@section('title', 'Productos')
@section('content')
<x-page-header title="Productos" subtitle="Las suscripciones que ofrece la app. El precio lo pone cada tienda; aquí van el id, el plan, el periodo y los días de prueba, y deben coincidir con lo creado en Play Console o App Store Connect.">
    <x-slot:actions>
        <x-btn variant="primary" icon="plus" type="button" onclick="document.getElementById('new-product').toggleAttribute('open')">Nuevo producto</x-btn>
    </x-slot:actions>
</x-page-header>

<details id="new-product" class="mb-6" @if ($errors->any() && ! old('_edit')) open @endif>
    <summary class="hidden"></summary>
    <x-card title="Nuevo producto">
        <form method="post" action="{{ route('admin.products.store') }}" class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
            @csrf
            @include('admin.products._fields', ['p' => null])
            <div class="sm:col-span-2 lg:col-span-3 flex justify-end gap-2">
                <x-btn variant="ghost" type="button" onclick="document.getElementById('new-product').removeAttribute('open')">Cancelar</x-btn>
                <x-btn variant="primary" icon="plus">Crear</x-btn>
            </div>
        </form>
    </x-card>
</details>

<x-card :padding="false">
    @if ($products->isEmpty())
        <x-empty title="Todavía no hay productos" icon="cube">
            Crea la suscripción en Play Console y después agrégala aquí: <span class="font-mono">mininoches_premium</span> con los planes <span class="font-mono">anual</span> y <span class="font-mono">mensual</span>.
        </x-empty>
    @else
    <div class="overflow-x-auto">
    <table class="table-base">
        <thead><tr><th>Producto</th><th>Tienda</th><th>Plan</th><th>Periodo</th><th class="text-right">Prueba</th><th class="text-right">Orden</th><th>Estado</th><th class="text-right">Acciones</th></tr></thead>
        <tbody>
        @foreach ($products as $p)
            <tr class="{{ $p->active ? '' : 'opacity-60' }}">
                <td class="font-mono font-medium">{{ $p->product_id }}</td>
                <td>{{ $p->platform === 'ios' ? 'App Store' : 'Google Play' }}</td>
                <td class="font-mono">{{ $p->base_plan ?: '—' }}</td>
                <td>{{ $p->period === 'P1Y' ? 'Anual' : 'Mensual' }}</td>
                <td class="text-right tabular-nums">{{ $p->trial_days }} días</td>
                <td class="text-right tabular-nums">{{ $p->position }}</td>
                <td>@if ($p->active)<x-badge color="green" dot>Activo</x-badge>@else<x-badge dot>Inactivo</x-badge>@endif</td>
                <td class="text-right whitespace-nowrap">
                    <x-btn variant="ghost" size="sm" icon="pencil" type="button" onclick="document.getElementById('edit-{{ $p->id }}').classList.toggle('hidden')">Editar</x-btn>
                    <form method="post" action="{{ route('admin.products.update', $p) }}" class="inline">@csrf
                        @if ($p->active)
                            <x-btn variant="danger-ghost" size="sm" name="toggle" value="1" data-confirm="La app dejará de ofrecer este plan. Quien ya lo pagó lo conserva." data-confirm-title="Desactivar producto" data-confirm-ok="Desactivar">Desactivar</x-btn>
                        @else
                            <x-btn variant="ghost" size="sm" name="toggle" value="1">Activar</x-btn>
                        @endif
                    </form>
                </td>
            </tr>
            <tr id="edit-{{ $p->id }}" class="hidden bg-slate-50">
                <td colspan="8">
                    <form method="post" action="{{ route('admin.products.update', $p) }}" class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 py-2">
                        @csrf <input type="hidden" name="_edit" value="1">
                        @include('admin.products._fields', ['p' => $p])
                        <div class="sm:col-span-2 lg:col-span-3 flex justify-end gap-2">
                            <x-btn variant="ghost" type="button" onclick="document.getElementById('edit-{{ $p->id }}').classList.add('hidden')">Cancelar</x-btn>
                            <x-btn variant="primary" icon="check">Guardar</x-btn>
                        </div>
                    </form>
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
    </div>
    @endif
</x-card>
@endsection
