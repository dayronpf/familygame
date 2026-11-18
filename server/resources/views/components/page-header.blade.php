@props(['title', 'subtitle' => null, 'back' => null, 'backLabel' => 'Volver'])
<div class="mb-6">
    @if ($back)
        <a href="{{ $back }}" class="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-brand-700 mb-2"><x-icon name="arrow-left" class="w-4 h-4" />{{ $backLabel }}</a>
    @endif
    <div class="flex flex-wrap items-start gap-3">
        <div class="min-w-0">
            <h1 class="text-2xl font-semibold text-slate-900 tracking-tight">{{ $title }}</h1>
            @if ($subtitle)<p class="text-sm text-slate-500 mt-1 max-w-3xl">{{ $subtitle }}</p>@endif
            {{ $meta ?? '' }}
        </div>
        @isset($actions)<div class="ml-auto flex flex-wrap items-center gap-2">{{ $actions }}</div>@endisset
    </div>
</div>
