@props(['title' => null, 'subtitle' => null, 'padding' => true])
<section {{ $attributes->merge(['class' => 'bg-white rounded-xl border border-slate-200 shadow-sm']) }}>
    @if ($title || isset($actions))
        <header class="flex flex-wrap items-center gap-2 px-5 py-3.5 border-b border-slate-100">
            <div>
                @if ($title)<h2 class="font-semibold text-slate-900">{{ $title }}</h2>@endif
                @if ($subtitle)<p class="text-xs text-slate-500 mt-0.5">{{ $subtitle }}</p>@endif
            </div>
            @isset($actions)<div class="ml-auto flex flex-wrap items-center gap-2">{{ $actions }}</div>@endisset
        </header>
    @endif
    <div class="{{ $padding ? 'p-5' : '' }}">{{ $slot }}</div>
</section>
