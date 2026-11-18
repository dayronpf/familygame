@if ($paginator->hasPages() || $paginator->total() > 0)
<nav class="flex flex-wrap items-center gap-3 justify-between text-sm" aria-label="Paginación">
    <p class="text-slate-600">
        @if ($paginator->total() > 0)
            Mostrando <span class="font-medium text-slate-900">{{ $paginator->firstItem() }}</span>–<span class="font-medium text-slate-900">{{ $paginator->lastItem() }}</span>
            de <span class="font-medium text-slate-900">{{ $paginator->total() }}</span>
        @endif
    </p>
    @if ($paginator->hasPages())
    <div class="inline-flex rounded-lg shadow-sm ring-1 ring-slate-300 bg-white overflow-hidden">
        @if ($paginator->onFirstPage())
            <span class="px-3 py-1.5 text-slate-300">‹ Anterior</span>
        @else
            <a href="{{ $paginator->previousPageUrl() }}" class="px-3 py-1.5 text-slate-700 hover:bg-slate-50" rel="prev">‹ Anterior</a>
        @endif
        @foreach ($elements as $element)
            @if (is_string($element))
                <span class="px-3 py-1.5 text-slate-400 border-l border-slate-200">…</span>
            @endif
            @if (is_array($element))
                @foreach ($element as $page => $url)
                    @if ($page == $paginator->currentPage())
                        <span aria-current="page" class="px-3 py-1.5 border-l border-slate-200 bg-brand-600 text-white font-medium">{{ $page }}</span>
                    @else
                        <a href="{{ $url }}" class="px-3 py-1.5 border-l border-slate-200 text-slate-700 hover:bg-slate-50">{{ $page }}</a>
                    @endif
                @endforeach
            @endif
        @endforeach
        @if ($paginator->hasMorePages())
            <a href="{{ $paginator->nextPageUrl() }}" class="px-3 py-1.5 border-l border-slate-200 text-slate-700 hover:bg-slate-50" rel="next">Siguiente ›</a>
        @else
            <span class="px-3 py-1.5 border-l border-slate-200 text-slate-300">Siguiente ›</span>
        @endif
    </div>
    @endif
</nav>
@endif
