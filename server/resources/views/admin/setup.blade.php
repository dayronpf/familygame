@extends('layouts.admin')
@section('title', 'Primer acceso')
@section('content')
<div class="max-w-sm mx-auto mt-16 bg-white rounded-xl shadow p-6">
    <h1 class="text-xl font-semibold mb-1">🌙 Mininoches</h1>
    <p class="text-sm text-slate-500 mb-6">Crea el SuperAdmin del panel. Este enlace deja de funcionar en cuanto lo crees.</p>
    @if ($errors->any())
        <div class="mb-4 text-sm text-red-700">{{ $errors->first() }}</div>
    @endif
    <form method="post" action="{{ route('admin.setup.store', $token) }}" class="space-y-4">
        @csrf
        <label class="block">
            <span class="text-sm font-medium">Correo</span>
            <input type="email" name="email" value="{{ old('email') }}" required autofocus autocomplete="username"
                   class="mt-1 w-full rounded-md border-slate-300 border px-3 py-2">
        </label>
        <label class="block">
            <span class="text-sm font-medium">Contraseña (mínimo 12 caracteres)</span>
            <input type="password" name="password" required minlength="12" autocomplete="new-password"
                   class="mt-1 w-full rounded-md border-slate-300 border px-3 py-2">
        </label>
        <label class="block">
            <span class="text-sm font-medium">Repite la contraseña</span>
            <input type="password" name="password_confirmation" required minlength="12" autocomplete="new-password"
                   class="mt-1 w-full rounded-md border-slate-300 border px-3 py-2">
        </label>
        <button class="w-full rounded-md bg-indigo-700 text-white py-2 font-medium hover:bg-indigo-800">Crear y entrar</button>
    </form>
</div>
@endsection
