<!doctype html>
<html lang="es" class="h-full">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>@yield('title', 'Panel') · Mininoches</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    {{-- Tailwind por CDN: el panel no necesita compilar nada. --}}
    <script src="https://cdn.tailwindcss.com/3.4.17"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: { sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'] },
                    colors: {
                        brand: { 50: '#eef2ff', 100: '#e0e7ff', 200: '#c7d2fe', 300: '#a5b4fc', 400: '#818cf8', 500: '#6366f1', 600: '#4f46e5', 700: '#4338ca', 800: '#3730a3', 900: '#312e81', 950: '#1e1b4b' },
                        night: { 900: '#14112e', 950: '#0d0b22' },
                    },
                },
            },
        };
    </script>
    <style type="text/tailwindcss">
        @layer components {
            .input { @apply block w-full rounded-lg border-0 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm ring-1 ring-inset ring-slate-300 placeholder:text-slate-400 focus:ring-2 focus:ring-inset focus:ring-brand-500; }
            .table-base { @apply w-full text-sm; }
            .table-base thead { @apply bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500; }
            .table-base th { @apply px-4 py-2.5 font-medium; }
            .table-base td { @apply px-4 py-3 align-middle; }
            .table-base tbody tr { @apply border-t border-slate-100; }
            .table-base tbody tr:hover { @apply bg-slate-50/70; }
            .nav-link { @apply flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-indigo-200/80 hover:bg-white/5 hover:text-white transition; }
            .nav-link.active { @apply bg-white/10 text-white; }
            .tab { @apply inline-flex items-center gap-2 border-b-2 border-transparent px-1 pb-3 text-sm font-medium text-slate-500 hover:text-slate-800 hover:border-slate-300 whitespace-nowrap; }
            .tab.active { @apply border-brand-600 text-brand-700; }
        }
        mark.token { background: #ede9fe; color: #5b21b6; border-radius: .25rem; padding: 0 .2rem; font-family: ui-monospace, monospace; font-size: .85em; }
    </style>
</head>
<body class="h-full bg-slate-50 font-sans text-slate-800 antialiased">
@auth
@php($nav = [
    ['admin.dashboard', 'Inicio', 'home', null],
    ['admin.stories.index', 'Cuentos', 'book', $navCounts['stories'] ?? null],
    ['admin.purchases.index', 'Compras', 'card', null],
    ['admin.ratings.index', 'Valoraciones', 'star', null],
    ['admin.products.index', 'Productos', 'cube', null],
    ['admin.audit.index', 'Auditoría', 'clipboard', null],
])
<div class="min-h-full lg:flex">
    {{-- Barra lateral --}}
    <aside id="sidebar" class="fixed inset-y-0 left-0 z-40 w-64 -translate-x-full lg:translate-x-0 transition-transform bg-night-950 flex flex-col">
        <a href="{{ route('admin.dashboard') }}" class="flex items-center gap-2 px-5 h-16 text-white">
            <span class="text-2xl">🌙</span><span class="font-semibold text-lg tracking-tight">Mininoches</span>
            <span class="ml-1 text-[10px] uppercase tracking-wider rounded bg-white/10 px-1.5 py-0.5 text-indigo-200">panel</span>
        </a>
        <nav class="flex-1 px-3 py-2 space-y-1 overflow-y-auto">
            @foreach ($nav as [$route, $label, $icon, $count])
                @php($active = request()->routeIs($route) || request()->routeIs(str_replace('.index', '.*', $route)))
                <a href="{{ route($route) }}" class="nav-link {{ $active ? 'active' : '' }}">
                    <x-icon :name="$icon" />{{ $label }}
                    @if ($count)<span class="ml-auto rounded-full bg-amber-400/90 text-night-950 text-xs font-semibold px-2 py-0.5">{{ $count }}</span>@endif
                </a>
            @endforeach
        </nav>
        <div class="border-t border-white/10 p-4">
            <div class="text-xs text-indigo-300/80 truncate mb-2" title="{{ auth()->user()->email }}">{{ auth()->user()->email }}</div>
            <form method="post" action="{{ route('admin.logout') }}">@csrf
                <button class="nav-link w-full px-0"><x-icon name="logout" />Cerrar sesión</button>
            </form>
        </div>
    </aside>
    <div id="sidebar-backdrop" class="fixed inset-0 z-30 bg-black/40 hidden lg:hidden" onclick="toggleSidebar(false)"></div>

    <div class="flex-1 lg:pl-64 min-w-0">
        {{-- Barra superior en el teléfono --}}
        <div class="lg:hidden sticky top-0 z-20 flex items-center gap-3 h-14 px-4 bg-night-950 text-white">
            <button onclick="toggleSidebar(true)" aria-label="Abrir menú"><x-icon name="menu" class="w-6 h-6" /></button>
            <span class="font-semibold">🌙 Mininoches</span>
        </div>
        <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            @yield('content')
        </main>
    </div>
</div>
@else
<main class="min-h-full">@yield('content')</main>
@endauth

{{-- Avisos --}}
<div id="toasts" class="fixed top-4 right-4 z-50 space-y-2 w-[22rem] max-w-[calc(100vw-2rem)]">
    @foreach (['ok' => ['green', 'check'], 'error' => ['red', 'alert']] as $key => [$tone, $icon])
        @if (session($key))
            <div data-toast class="flex items-start gap-3 rounded-xl bg-white shadow-lg ring-1 ring-slate-200 p-4 text-sm">
                <span class="{{ $tone === 'green' ? 'text-emerald-600' : 'text-rose-600' }}"><x-icon :name="$icon" /></span>
                <div class="flex-1 text-slate-800">{{ session($key) }}</div>
                <button onclick="this.closest('[data-toast]').remove()" class="text-slate-400 hover:text-slate-600" aria-label="Cerrar"><x-icon name="x" class="w-4 h-4" /></button>
            </div>
        @endif
    @endforeach
    @if ($errors->any())
        <div data-toast data-sticky class="flex items-start gap-3 rounded-xl bg-white shadow-lg ring-1 ring-rose-200 p-4 text-sm">
            <span class="text-rose-600"><x-icon name="alert" /></span>
            <div class="flex-1 text-slate-800"><p class="font-medium mb-1">Revisa lo marcado:</p>@foreach ($errors->all() as $e)<div>{{ $e }}</div>@endforeach</div>
            <button onclick="this.closest('[data-toast]').remove()" class="text-slate-400 hover:text-slate-600" aria-label="Cerrar"><x-icon name="x" class="w-4 h-4" /></button>
        </div>
    @endif
</div>

{{-- Confirmación (para cualquier botón o formulario con data-confirm) --}}
<dialog id="confirm" class="rounded-2xl p-0 shadow-2xl backdrop:bg-slate-900/50 w-[28rem] max-w-[calc(100vw-2rem)]">
    <form method="dialog" class="p-6">
        <div class="flex gap-4">
            <span id="confirm-icon" class="shrink-0 w-10 h-10 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center"><x-icon name="alert" /></span>
            <div>
                <h3 id="confirm-title" class="font-semibold text-slate-900">¿Seguro?</h3>
                <p id="confirm-text" class="text-sm text-slate-600 mt-1"></p>
            </div>
        </div>
        <div class="mt-6 flex justify-end gap-2">
            <button value="no" class="rounded-lg px-3.5 py-2 text-sm font-medium text-slate-700 ring-1 ring-slate-300 hover:bg-slate-50">Cancelar</button>
            <button value="si" id="confirm-ok" class="rounded-lg px-3.5 py-2 text-sm font-medium text-white bg-rose-600 hover:bg-rose-700">Confirmar</button>
        </div>
    </form>
</dialog>

<script>
    function toggleSidebar(open) {
        document.getElementById('sidebar').classList.toggle('-translate-x-full', !open);
        document.getElementById('sidebar-backdrop').classList.toggle('hidden', !open);
    }
    // Los avisos se van solos (menos los errores de formulario).
    document.querySelectorAll('[data-toast]:not([data-sticky])').forEach(t => setTimeout(() => t.remove(), 6000));

    // Confirmación: <button data-confirm="texto" data-confirm-title="…" data-confirm-ok="Eliminar" data-confirm-tone="danger|primary">
    (() => {
        const dlg = document.getElementById('confirm');
        let pending = null;
        document.addEventListener('click', e => {
            const el = e.target.closest('[data-confirm]');
            if (!el || el.dataset.confirmed) return;
            e.preventDefault();
            pending = el;
            document.getElementById('confirm-title').textContent = el.dataset.confirmTitle || '¿Seguro?';
            document.getElementById('confirm-text').textContent = el.dataset.confirm;
            const ok = document.getElementById('confirm-ok');
            ok.textContent = el.dataset.confirmOk || 'Confirmar';
            const primary = el.dataset.confirmTone === 'primary';
            ok.className = 'rounded-lg px-3.5 py-2 text-sm font-medium text-white ' + (primary ? 'bg-brand-600 hover:bg-brand-700' : 'bg-rose-600 hover:bg-rose-700');
            document.getElementById('confirm-icon').className = 'shrink-0 w-10 h-10 rounded-full flex items-center justify-center ' + (primary ? 'bg-brand-100 text-brand-600' : 'bg-rose-100 text-rose-600');
            dlg.showModal();
        });
        dlg.addEventListener('close', () => {
            if (dlg.returnValue === 'si' && pending) {
                pending.dataset.confirmed = '1';
                if (pending.tagName === 'A') location.href = pending.href;
                else if (pending.form) pending.form.requestSubmit(pending);
                else pending.click();
            }
            pending = null;
        });
    })();

    // Selección múltiple: [data-check-all], [data-row-check] y una barra [data-bulk] con [data-bulk-count]
    (() => {
        const all = document.querySelector('[data-check-all]');
        const rows = () => [...document.querySelectorAll('[data-row-check]')];
        const bar = document.querySelector('[data-bulk]');
        const sync = () => {
            const n = rows().filter(r => r.checked).length;
            if (bar) { bar.classList.toggle('hidden', n === 0); bar.querySelector('[data-bulk-count]').textContent = n; }
            if (all) { all.checked = n > 0 && n === rows().length; all.indeterminate = n > 0 && n < rows().length; }
        };
        all?.addEventListener('change', () => { rows().forEach(r => r.checked = all.checked); sync(); });
        document.addEventListener('change', e => { if (e.target.matches('[data-row-check]')) sync(); });
        sync();
    })();

    // Copiar al portapapeles: <button data-copy="texto">
    document.addEventListener('click', e => {
        const el = e.target.closest('[data-copy]');
        if (!el) return;
        navigator.clipboard.writeText(el.dataset.copy).then(() => {
            const old = el.innerHTML; el.innerHTML = '¡Copiado!'; setTimeout(() => el.innerHTML = old, 1200);
        });
    });
</script>
@stack('scripts')
</body>
</html>
