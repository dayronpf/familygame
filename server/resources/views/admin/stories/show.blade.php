@extends('layouts.admin')
@section('title', $premise->title)
@section('content')
@php($hl = fn (string $text) => preg_replace('/\{[^{}\s]+\}/u', '<mark class="token">$0</mark>', e($text)))
<a href="{{ route('admin.stories.index') }}" class="text-sm text-indigo-700 hover:underline">← Cuentos</a>
<div class="flex flex-wrap items-start gap-4 mt-2 mb-6">
    <div>
        <h1 class="text-2xl font-semibold">{{ $premise->title }}</h1>
        <p class="text-sm text-slate-500">{{ $premise->ref }} · {{ $premise->pack?->name }} {{ $premise->pack_version }} ·
            {{ implode(', ', $premise->ages ?? []) }} años · {{ $premise->pack?->moralName($premise->value) }} ·
            {{ $premise->beat_count }} escenas, {{ $premise->variant_count }} variantes</p>
        @unless ($premise->in_pack)<p class="text-sm text-rose-700 mt-1">Ya no está en el pack (se retiró en la última importación).</p>@endunless
    </div>
    <div class="ml-auto flex items-center gap-2">
        @include('admin.stories._status', ['status' => $premise->review_status])
        <form method="post" action="{{ route('admin.stories.free', $premise) }}">@csrf
            <button class="rounded-md border px-3 py-1.5 text-sm {{ $premise->is_free ? 'bg-sky-100 border-sky-300 text-sky-900' : 'bg-white' }}">
                {{ $premise->is_free ? '★ Gratis (quitar)' : '☆ Hacer gratis' }}</button>
        </form>
    </div>
</div>

<div class="grid lg:grid-cols-3 gap-6">
    <div class="lg:col-span-2 space-y-4">
        <p class="text-xs text-slate-500">Las <mark class="token">{marcas}</mark> se reemplazan en la app por el héroe, el ayudante, los lugares, etc. Cada escena muestra todas sus variantes: la app elige una al azar.</p>
        @foreach ($premise->beats as $i => $beat)
            <section class="bg-white rounded-xl border border-slate-200 p-4">
                <h2 class="font-semibold mb-2">{{ $i + 1 }}. {{ str_replace('_', ' ', $beat['id']) }} <span class="text-xs font-normal text-slate-400">{{ $premise->premise_id }}.{{ $beat['id'] }}</span></h2>
                @foreach ($beat['variants'] as $v)
                    @php($fid = $premise->premise_id.'.'.$beat['id'].'.'.$v['id'])
                    @php($fs = $stats['byFragment'][$fid] ?? null)
                    <div class="border-l-4 border-indigo-200 pl-3 py-1 mb-3">
                        <div class="text-xs text-slate-400 mb-1">Variante {{ $v['id'] }}
                            @if ($fs) · {{ number_format($fs['sum'] / $fs['n'], 1, ',', '') }} de promedio en {{ $fs['n'] }} valoraciones @endif</div>
                        <p class="leading-relaxed">{!! $hl($v['text']) !!}</p>
                    </div>
                @endforeach
                @if (! empty($beat['choice']))
                    <div class="mt-2 rounded-lg bg-violet-50 border border-violet-200 p-3 text-sm">
                        <div class="font-medium">❓ {!! $hl($beat['choice']['ask']) !!}</div>
                        <ul class="list-disc ml-5 mt-1">
                            @foreach ($beat['choice']['options'] as $o) <li>{{ $o['label'] }} <span class="text-xs text-slate-400">({{ $o['id'] }})</span></li> @endforeach
                        </ul>
                    </div>
                @endif
            </section>
        @endforeach
    </div>

    <aside class="space-y-4">
        <section class="bg-white rounded-xl border border-slate-200 p-4">
            <h2 class="font-semibold mb-3">Revisión</h2>
            <form method="post" action="{{ route('admin.stories.review', $premise) }}" class="space-y-3">
                @csrf
                <textarea name="notes" rows="4" placeholder="Notas (qué corregir, por qué se rechaza…)" class="w-full border rounded-md px-2 py-1 text-sm">{{ old('notes', $premise->review_notes) }}</textarea>
                <div class="flex flex-wrap gap-2">
                    <button name="status" value="aprobado" class="rounded-md bg-emerald-600 text-white px-3 py-1.5 text-sm hover:bg-emerald-700">Aprobar</button>
                    <button name="status" value="rechazado" class="rounded-md bg-rose-600 text-white px-3 py-1.5 text-sm hover:bg-rose-700"
                            onclick="return confirm('¿Rechazar? La app dejará de mostrar este cuento.')">Rechazar</button>
                    <button name="status" value="pendiente" class="rounded-md border px-3 py-1.5 text-sm">Dejar pendiente</button>
                </div>
            </form>
            @if ($premise->reviewed_at)<p class="text-xs text-slate-500 mt-2">Última revisión: {{ $premise->reviewed_at->format('d/m/Y H:i') }}</p>@endif
        </section>

        <section class="bg-white rounded-xl border border-slate-200 p-4">
            <h2 class="font-semibold mb-2">Valoraciones</h2>
            @if ($stats['count'] === 0)
                <p class="text-sm text-slate-500">Aún no hay valoraciones de este cuento.</p>
            @else
                <p class="text-sm mb-2"><b>{{ number_format($stats['avg'], 2, ',', '') }}</b> de promedio en {{ $stats['count'] }} valoraciones
                    <span class="text-slate-400">(versiones {{ $stats['versions']->implode(', ') }})</span></p>
                @php($labels = [1 => 'Nada', 2 => 'Poco', 3 => 'Regular', 4 => 'Bien', 5 => '¡Me encantó!'])
                @foreach (array_reverse($stats['distribution'], true) as $n => $c)
                    <div class="flex items-center gap-2 text-xs mb-1">
                        <span class="w-20">{{ $n }} · {{ $labels[$n] }}</span>
                        <div class="flex-1 bg-slate-100 rounded h-2"><div class="bg-indigo-500 h-2 rounded" style="width: {{ $stats['count'] ? round($c * 100 / $stats['count']) : 0 }}%"></div></div>
                        <span class="w-8 text-right">{{ $c }}</span>
                    </div>
                @endforeach
                <h3 class="font-medium text-sm mt-3 mb-1">Motivos de notas bajas</h3>
                <ul class="text-sm">
                    @foreach ($stats['reasons'] as $code => $c)
                        <li class="flex justify-between"><span>{{ \App\Models\StoryRating::REASONS[$code] ?? $code }}</span><span>{{ $c }}</span></li>
                    @endforeach
                </ul>
            @endif
        </section>

        @if ($logs->isNotEmpty())
            <section class="bg-white rounded-xl border border-slate-200 p-4">
                <h2 class="font-semibold mb-2">Historial</h2>
                <ul class="text-xs space-y-1">
                    @foreach ($logs as $log)
                        <li>{{ $log->created_at->format('d/m/Y H:i') }} · {{ $log->action }} · {{ json_encode($log->details, JSON_UNESCAPED_UNICODE) }}</li>
                    @endforeach
                </ul>
            </section>
        @endif
    </aside>
</div>
@endsection
