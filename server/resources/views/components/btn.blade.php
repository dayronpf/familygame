@props(['variant' => 'secondary', 'size' => 'md', 'href' => null, 'icon' => null, 'type' => 'submit'])
@php($base = 'inline-flex items-center justify-center gap-1.5 rounded-lg font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-1 focus-visible:ring-brand-500 disabled:opacity-50 disabled:pointer-events-none whitespace-nowrap')
@php($sizes = ['sm' => 'text-xs px-2.5 py-1.5', 'md' => 'text-sm px-3.5 py-2', 'lg' => 'text-sm px-4 py-2.5'])
@php($variants = [
    'primary' => 'bg-brand-600 text-white shadow-sm hover:bg-brand-700',
    'secondary' => 'bg-white text-slate-700 ring-1 ring-inset ring-slate-300 shadow-sm hover:bg-slate-50',
    'danger' => 'bg-rose-600 text-white shadow-sm hover:bg-rose-700',
    'danger-ghost' => 'text-rose-700 hover:bg-rose-50',
    'success' => 'bg-emerald-600 text-white shadow-sm hover:bg-emerald-700',
    'ghost' => 'text-slate-600 hover:bg-slate-100 hover:text-slate-900',
])
@php($classes = $base.' '.($sizes[$size] ?? $sizes['md']).' '.($variants[$variant] ?? $variants['secondary']))
@if ($href)
    <a href="{{ $href }}" {{ $attributes->merge(['class' => $classes]) }}>@if ($icon)<x-icon :name="$icon" class="w-4 h-4" />@endif{{ $slot }}</a>
@else
    <button type="{{ $type }}" {{ $attributes->merge(['class' => $classes]) }}>@if ($icon)<x-icon :name="$icon" class="w-4 h-4" />@endif{{ $slot }}</button>
@endif
