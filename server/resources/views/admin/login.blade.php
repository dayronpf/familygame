@extends('layouts.admin')
@section('title', 'Entrar')
@section('content')
<div class="max-w-sm mx-auto mt-16 bg-white rounded-xl shadow p-6">
    <h1 class="text-xl font-semibold mb-1">🌙 Mininoches</h1>
    <p class="text-sm text-slate-500 mb-6">Panel del SuperAdmin</p>
    <form method="post" action="{{ route('admin.login.post') }}" class="space-y-4">
        @csrf
        <label class="block">
            <span class="text-sm font-medium">Correo</span>
            <input type="email" name="email" value="{{ old('email') }}" required autofocus autocomplete="username"
                   class="mt-1 w-full rounded-md border-slate-300 border px-3 py-2">
        </label>
        <label class="block">
            <span class="text-sm font-medium">Contraseña</span>
            <input type="password" name="password" required autocomplete="current-password"
                   class="mt-1 w-full rounded-md border-slate-300 border px-3 py-2">
        </label>
        <label class="flex items-center gap-2 text-sm"><input type="checkbox" name="remember" value="1"> Recordarme en este equipo</label>
        <button class="w-full rounded-md bg-indigo-700 text-white py-2 font-medium hover:bg-indigo-800">Entrar</button>
    </form>
    <p class="text-xs text-slate-400 mt-6">No hay registro. El SuperAdmin se crea en el servidor con <code>php artisan mininoches:admin</code>.</p>
</div>
@endsection
