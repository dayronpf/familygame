@extends('layouts.admin')
@section('title', 'Entrar')
@section('content')
<div class="min-h-screen flex items-center justify-center bg-night-950 px-4" style="background-image: radial-gradient(circle at 20% 20%, rgba(99,102,241,.25), transparent 40%), radial-gradient(circle at 80% 80%, rgba(139,92,246,.2), transparent 40%)">
    <div class="w-full max-w-sm">
        <div class="text-center mb-6 text-white">
            <div class="text-5xl mb-2">🌙</div>
            <h1 class="text-2xl font-semibold tracking-tight">Mininoches</h1>
            <p class="text-sm text-indigo-200/80">Panel de administración</p>
        </div>
        <form method="post" action="{{ route('admin.login.post') }}" class="bg-white rounded-2xl shadow-2xl p-6 space-y-4">
            @csrf
            <x-field label="Correo" name="email">
                <input type="email" name="email" value="{{ old('email') }}" required autofocus autocomplete="username" class="input">
            </x-field>
            <x-field label="Contraseña" name="password">
                <input type="password" name="password" required autocomplete="current-password" class="input">
            </x-field>
            <label class="flex items-center gap-2 text-sm text-slate-600"><input type="checkbox" name="remember" value="1" class="rounded border-slate-300 text-brand-600"> Recordarme en este equipo</label>
            <x-btn variant="primary" size="lg" class="w-full">Entrar</x-btn>
        </form>
        <p class="text-center text-xs text-indigo-200/60 mt-6">No hay registro: el único usuario se crea en el servidor.</p>
    </div>
</div>
@endsection
