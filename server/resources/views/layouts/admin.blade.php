<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>@yield('title', 'Panel') · Mininoches</title>
    {{-- Tailwind por CDN: el panel no necesita compilar nada. --}}
    <script src="https://cdn.tailwindcss.com/3.4.17"></script>
    <style>
        mark.token { background: #ede9fe; color: #5b21b6; border-radius: .25rem; padding: 0 .2rem; font-family: ui-monospace, monospace; font-size: .85em; }
    </style>
</head>
<body class="bg-slate-50 text-slate-800 min-h-screen">
@auth
    <header class="bg-indigo-950 text-indigo-50">
        <div class="max-w-7xl mx-auto px-4 py-3 flex flex-wrap items-center gap-x-6 gap-y-2">
            <a href="{{ route('admin.dashboard') }}" class="font-semibold text-lg tracking-tight">🌙 Mininoches</a>
            <nav class="flex flex-wrap gap-1 text-sm">
                @php($items = [
                    'admin.dashboard' => 'Panel',
                    'admin.stories.index' => 'Cuentos',
                    'admin.purchases.index' => 'Compras y suscripciones',
                    'admin.codes.index' => 'Códigos',
                    'admin.ratings.index' => 'Valoraciones',
                    'admin.products.index' => 'Productos',
                    'admin.audit.index' => 'Auditoría',
                ])
                @foreach ($items as $route => $label)
                    @php($active = request()->routeIs(str_replace('.index', '.*', $route)) || request()->routeIs($route))
                    <a href="{{ route($route) }}" class="px-3 py-1.5 rounded-md {{ $active ? 'bg-indigo-700 text-white' : 'hover:bg-indigo-900' }}">{{ $label }}</a>
                @endforeach
            </nav>
            <form method="post" action="{{ route('admin.logout') }}" class="ml-auto text-sm">
                @csrf
                <span class="opacity-70 mr-2">{{ auth()->user()->email }}</span>
                <button class="underline hover:no-underline">Salir</button>
            </form>
        </div>
    </header>
@endauth
<main class="max-w-7xl mx-auto px-4 py-6">
    @if (session('ok'))
        <div class="mb-4 rounded-md bg-emerald-50 border border-emerald-200 text-emerald-800 px-4 py-2">{{ session('ok') }}</div>
    @endif
    @if (session('error'))
        <div class="mb-4 rounded-md bg-rose-50 border border-rose-200 text-rose-800 px-4 py-2">{{ session('error') }}</div>
    @endif
    @if ($errors->any())
        <div class="mb-4 rounded-md bg-rose-50 border border-rose-200 text-rose-800 px-4 py-2">
            @foreach ($errors->all() as $e) <div>{{ $e }}</div> @endforeach
        </div>
    @endif
    @yield('content')
</main>
</body>
</html>
