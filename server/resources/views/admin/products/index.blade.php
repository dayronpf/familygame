@extends('layouts.admin')
@section('title', 'Productos')
@section('content')
<h1 class="text-2xl font-semibold mb-1">Productos</h1>
<p class="text-sm text-slate-600 mb-4">Las suscripciones que la app muestra en el catálogo. El precio lo pone cada tienda; aquí solo el id, el plan base, el periodo y los días de prueba. El id y el plan deben coincidir con Play Console / App Store Connect.</p>
<div class="space-y-3 mb-8">
@foreach ($products as $p)
    <form method="post" action="{{ route('admin.products.update', $p) }}" class="bg-white rounded-xl border border-slate-200 p-3 grid sm:grid-cols-3 lg:grid-cols-8 gap-2 items-end text-sm {{ $p->active ? '' : 'opacity-60' }}">
        @csrf
        @include('admin.products._fields', ['p' => $p])
        <button class="rounded-md bg-indigo-700 text-white px-3 py-1.5">Guardar</button>
        <button name="toggle" value="1" class="rounded-md border px-3 py-1.5">{{ $p->active ? 'Desactivar' : 'Activar' }}</button>
    </form>
@endforeach
</div>
<h2 class="font-semibold mb-2">Nuevo producto</h2>
<form method="post" action="{{ route('admin.products.store') }}" class="bg-white rounded-xl border border-slate-200 p-3 grid sm:grid-cols-3 lg:grid-cols-8 gap-2 items-end text-sm">
    @csrf
    @include('admin.products._fields', ['p' => null])
    <button class="rounded-md bg-indigo-700 text-white px-3 py-1.5">Crear</button>
</form>
@endsection
