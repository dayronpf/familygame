@extends('layouts.admin')
@section('title', $story['title'] ?? $premise->title)
@section('content')
@php($hl = fn (string $text) => preg_replace('/\{[^{}\s]+\}/u', '<mark class="token">$0</mark>', e($text)))
@php($P = \App\Models\Premise::class)

<x-page-header :title="$story['title'] ?? $premise->title" :back="route('admin.stories.index')" back-label="Cuentos">
    <x-slot:meta>
        <div class="flex flex-wrap items-center gap-2 mt-2 text-sm text-slate-500">
            <span class="font-mono text-xs">{{ $premise->ref }}</span><span>·</span>
            <span>{{ $premise->pack?->name }}</span><span>·</span>
            <span>{{ implode(', ', $story['ages'] ?? $premise->ages ?? []) }} años</span><span>·</span>
            <span>{{ $premise->pack?->moralName($story['value'] ?? $premise->value) }}</span><span>·</span>
            <span>{{ count($story['beats'] ?? []) }} escenas</span>
        </div>
        <div class="flex flex-wrap gap-1.5 mt-2">@include('admin.stories._status', ['premise' => $premise])
            @if ($premise->is_free)<x-badge color="blue">Gratis</x-badge>@endif</div>
    </x-slot:meta>
    <x-slot:actions>
        @if ($premise->draft_op !== 'eliminar')
            <x-btn variant="primary" icon="pencil" :href="route('admin.stories.edit', $premise)">Editar</x-btn>
        @endif
    </x-slot:actions>
</x-page-header>

@if ($premise->draft_state === $P::FAILED)
    <div class="mb-4 rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-800">
        <p class="font-medium flex items-center gap-2"><x-icon name="alert" class="w-4 h-4" />No se pudo publicar</p>
        <pre class="mt-2 whitespace-pre-wrap font-sans">{{ $premise->draft_error }}</pre>
        <p class="mt-2">Corrige el cuento y vuelve a publicarlo.</p>
    </div>
@endif
@if ($premise->draft !== null && $premise->data !== null && $premise->draft_op !== 'eliminar')
    <div class="mb-4 rounded-xl border border-brand-200 bg-brand-50 px-4 py-3 text-sm text-brand-900 flex flex-wrap items-center gap-3">
        <x-icon name="pencil" class="w-4 h-4" />
        @if ($showDraft)
            Estás viendo <b>los cambios sin publicar</b>.
            <a class="underline" href="{{ request()->fullUrlWithQuery(['version' => 'publicada']) }}">Ver lo publicado</a>
        @else
            Estás viendo <b>lo publicado</b> (lo que tiene la app).
            <a class="underline" href="{{ request()->fullUrlWithQuery(['version' => null]) }}">Ver los cambios sin publicar</a>
        @endif
    </div>
@endif

<div class="grid lg:grid-cols-3 gap-6">
    <div class="lg:col-span-2 min-w-0">
        <div class="border-b border-slate-200 mb-4">
            <nav class="flex gap-6">
                @foreach (['leer' => 'Leer el cuento', 'valoraciones' => 'Valoraciones ('.$stats['count'].')', 'historial' => 'Historial'] as $key => $label)
                    <a href="{{ request()->fullUrlWithQuery(['vista' => $key === 'leer' ? null : $key]) }}" class="tab {{ $view === $key ? 'active' : '' }}">{{ $label }}</a>
                @endforeach
            </nav>
        </div>

        @if ($view === 'leer')
            @if (! empty($story['lesson']))
                <p class="mb-4 rounded-xl bg-amber-50 border border-amber-200 px-4 py-3 text-sm text-amber-900"><b>Enseñanza:</b> {{ $story['lesson'] }}</p>
            @endif
            <p class="text-xs text-slate-500 mb-3">Las <mark class="token">{marcas}</mark> las cambia la app por el nombre del protagonista, el ayudante, los lugares… Si una escena tiene varias versiones, la app elige una.</p>
            <ol class="space-y-3">
                @foreach ($story['beats'] ?? [] as $i => $beat)
                    <li class="bg-white rounded-xl border border-slate-200 p-4 shadow-sm">
                        <div class="flex items-center gap-2 mb-2">
                            <span class="w-6 h-6 rounded-full bg-brand-50 text-brand-700 text-xs font-semibold flex items-center justify-center">{{ $i + 1 }}</span>
                            <span class="text-xs text-slate-400 font-mono">{{ $beat['id'] }}</span>
                            @if (count($beat['variants'] ?? []) > 1)<x-badge>{{ count($beat['variants']) }} versiones</x-badge>@endif
                        </div>
                        @foreach ($beat['variants'] ?? [] as $vi => $v)
                            @php($fid = $premise->premise_id.'.'.$beat['id'].'.'.$v['id'])
                            @php($fs = $stats['byFragment'][$fid] ?? null)
                            <div class="{{ $vi > 0 ? 'mt-3 pt-3 border-t border-dashed border-slate-200' : '' }}">
                                @if (count($beat['variants']) > 1 || $fs)
                                    <div class="text-xs text-slate-400 mb-1">Versión {{ chr(65 + $vi) }}@if ($fs) · <x-icon name="star" class="w-3 h-3 inline text-amber-400" /> {{ number_format($fs['sum'] / $fs['n'], 1, ',', '') }} en {{ $fs['n'] }} valoraciones @endif</div>
                                @endif
                                <p class="leading-relaxed text-slate-800">{!! $hl($v['text'] ?? '') !!}</p>
                            </div>
                        @endforeach
                        @if (! empty($beat['choice']))
                            <div class="mt-3 rounded-lg bg-violet-50 border border-violet-200 p-3 text-sm">
                                <div class="font-medium">❓ {!! $hl($beat['choice']['ask'] ?? '') !!}</div>
                                <ul class="list-disc ml-5 mt-1">@foreach ($beat['choice']['options'] ?? [] as $o)<li>{{ $o['label'] ?? $o['id'] }}</li>@endforeach</ul>
                            </div>
                        @endif
                    </li>
                @endforeach
            </ol>
        @elseif ($view === 'valoraciones')
            <x-card>
                @if ($stats['count'] === 0)
                    <x-empty title="Aún no hay valoraciones" icon="star">Cuando las familias valoren este cuento en la app, aparecerán aquí.</x-empty>
                @else
                    <div class="flex items-baseline gap-2 mb-4"><span class="text-4xl font-semibold">{{ number_format($stats['avg'], 1, ',', '') }}</span><span class="text-slate-500">de 5 · {{ $stats['count'] }} valoraciones</span></div>
                    @php($labels = [1 => 'Nada', 2 => 'Poco', 3 => 'Regular', 4 => 'Bien', 5 => '¡Me encantó!'])
                    @foreach (array_reverse($stats['distribution'], true) as $n => $c)
                        <div class="flex items-center gap-3 text-sm mb-1.5">
                            <span class="w-28 text-slate-600">{{ $n }} · {{ $labels[$n] }}</span>
                            <div class="flex-1 bg-slate-100 rounded-full h-2"><div class="bg-amber-400 h-2 rounded-full" style="width: {{ round($c * 100 / $stats['count']) }}%"></div></div>
                            <span class="w-8 text-right tabular-nums">{{ $c }}</span>
                        </div>
                    @endforeach
                    <h3 class="font-medium mt-6 mb-2">Motivos de las notas bajas</h3>
                    <ul class="text-sm divide-y divide-slate-100">
                        @foreach ($stats['reasons'] as $code => $c)
                            <li class="flex justify-between py-1.5"><span>{{ \App\Models\StoryRating::REASONS[$code] ?? $code }}</span><span class="tabular-nums">{{ $c }}</span></li>
                        @endforeach
                    </ul>
                    <p class="text-xs text-slate-400 mt-4">Versiones del pack valoradas: {{ $stats['versions']->implode(', ') }}</p>
                @endif
            </x-card>
        @else
            <x-card :padding="false">
                @if ($logs->isEmpty())
                    <x-empty title="Sin cambios registrados" icon="clipboard" />
                @else
                    <ul class="divide-y divide-slate-100 text-sm">
                        @foreach ($logs as $log)
                            <li class="px-5 py-3 flex flex-wrap gap-x-3">
                                <span class="text-slate-500 whitespace-nowrap">{{ $log->created_at->format('d/m/Y H:i') }}</span>
                                <span class="font-medium">{{ \App\Models\AuditLog::label($log->action) }}</span>
                                <span class="text-slate-500">{{ $log->user?->email }}</span>
                            </li>
                        @endforeach
                    </ul>
                @endif
            </x-card>
        @endif
    </div>

    <aside class="space-y-4">
        {{-- Publicación --}}
        @if ($premise->hasDraft())
            <x-card title="Cambios sin publicar">
                @if ($premise->draft_op === 'eliminar')
                    <p class="text-sm text-slate-600 mb-3">Este cuento ya no sale en la app. Se quitará del pack en la próxima publicación.</p>
                    <form method="post" action="{{ route('admin.stories.restore', $premise) }}">@csrf
                        <x-btn variant="secondary" icon="refresh" class="w-full">Cancelar la eliminación</x-btn></form>
                @elseif (in_array($premise->draft_state, [$P::QUEUED, $P::PUBLISHING], true))
                    <p class="text-sm text-slate-600">En cola desde {{ $premise->draft_updated_at?->format('d/m/Y H:i') }}. La app lo recibirá cuando termine la publicación.</p>
                @else
                    <p class="text-sm text-slate-600 mb-3">Guardado el {{ $premise->draft_updated_at?->format('d/m/Y H:i') }}. La app sigue mostrando lo publicado hasta que lo publiques.</p>
                    <div class="flex flex-col gap-2">
                        <form method="post" action="{{ route('admin.stories.publish', $premise) }}">@csrf
                            <x-btn variant="primary" icon="send" class="w-full">Publicar</x-btn></form>
                        <form method="post" action="{{ route('admin.stories.discard', $premise) }}">@csrf
                            <x-btn variant="ghost" class="w-full" data-confirm="{{ $premise->isUnpublished() ? 'Se borrará este cuento nuevo.' : 'Se perderán los cambios y queda lo publicado.' }}" data-confirm-title="Descartar cambios" data-confirm-ok="Descartar">Descartar cambios</x-btn></form>
                    </div>
                @endif
            </x-card>
        @endif

        {{-- En la app --}}
        <x-card title="En la app">
            <dl class="text-sm space-y-2">
                <div class="flex justify-between gap-2"><dt class="text-slate-500">Se muestra</dt><dd>{{ $premise->review_status === $P::REJECTED ? 'No (oculto)' : ($storyCatalog ? 'Sí' : 'No, no está en el catálogo') }}</dd></div>
                @if ($storyCatalog)
                    <div class="flex justify-between gap-2"><dt class="text-slate-500">Protagonista</dt><dd>{{ $storyCatalog['heroe'] ?? '—' }} ({{ ($storyCatalog['generoHeroe'] ?? '') === 'f' ? 'niña' : 'niño' }})</dd></div>
                    <div class="flex justify-between gap-2"><dt class="text-slate-500">Edad en la app</dt><dd>{{ $storyCatalog['edad'] ?? '—' }} años</dd></div>
                @endif
                <div class="flex justify-between gap-2"><dt class="text-slate-500">Acceso</dt><dd>{{ $premise->is_free ? 'Gratis para todos' : 'Con suscripción' }}</dd></div>
            </dl>
            @unless ($premise->isUnpublished() || $premise->draft_op === 'eliminar')
                <div class="mt-4 flex flex-col gap-2">
                    <form method="post" action="{{ route('admin.stories.free', $premise) }}">@csrf
                        <x-btn variant="secondary" :icon="$premise->is_free ? 'x' : 'gift'" class="w-full">{{ $premise->is_free ? 'Quitar de los gratis' : 'Hacer gratis' }}</x-btn></form>
                    <form method="post" action="{{ route('admin.stories.review', $premise) }}">@csrf
                        @if ($premise->review_status === $P::REJECTED)
                            <x-btn variant="secondary" icon="eye" class="w-full" name="status" value="aprobado">Mostrar en la app</x-btn>
                        @else
                            <x-btn variant="secondary" icon="eye-off" class="w-full" name="status" value="rechazado" data-confirm="La app dejará de mostrarlo. Puedes volver a mostrarlo cuando quieras." data-confirm-title="Ocultar de la app" data-confirm-ok="Ocultar">Ocultar de la app</x-btn>
                        @endif
                    </form>
                </div>
            @endunless
        </x-card>

        {{-- Revisión --}}
        @unless ($premise->isUnpublished())
            <x-card title="Revisión">
                <form method="post" action="{{ route('admin.stories.review', $premise) }}" class="space-y-3">@csrf
                    <textarea name="notes" rows="3" placeholder="Notas internas: qué corregir, por qué se oculta…" class="input">{{ old('notes', $premise->review_notes) }}</textarea>
                    <div class="flex flex-wrap gap-2">
                        <x-btn variant="success" size="sm" icon="check" name="status" value="aprobado">Aprobar</x-btn>
                        <x-btn variant="secondary" size="sm" name="status" value="pendiente">Dejar por revisar</x-btn>
                    </div>
                </form>
                @if ($premise->reviewed_at)<p class="text-xs text-slate-500 mt-3">Última revisión: {{ $premise->reviewed_at->format('d/m/Y H:i') }}</p>@endif
            </x-card>
        @endunless

        {{-- Más acciones --}}
        <x-card title="Más acciones">
            <div class="flex flex-col gap-2">
                <form method="post" action="{{ route('admin.stories.duplicate', $premise) }}">@csrf
                    <x-btn variant="secondary" icon="copy" class="w-full">Duplicar como cuento nuevo</x-btn></form>
                @if ($premise->draft_op !== 'eliminar')
                    <form method="post" action="{{ route('admin.stories.destroy', $premise) }}">@csrf @method('DELETE')
                        <x-btn variant="danger-ghost" icon="trash" class="w-full"
                            data-confirm="{{ $premise->isUnpublished() ? 'Se borrará este cuento nuevo. No se puede deshacer.' : 'Dejará de salir en la app ahora y se quitará del pack en la próxima publicación. Hasta entonces puedes cancelarlo.' }}"
                            data-confirm-title="Eliminar «{{ $story['title'] ?? $premise->title }}»" data-confirm-ok="Eliminar">Eliminar cuento</x-btn></form>
                @endif
            </div>
        </x-card>
    </aside>
</div>
@endsection
