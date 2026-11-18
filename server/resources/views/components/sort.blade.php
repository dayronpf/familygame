@props(['column', 'label', 'sort', 'dir', 'class' => ''])
@php($active = $sort === $column)
@php($next = $active && $dir === 'asc' ? 'desc' : 'asc')
<th class="px-4 py-2.5 font-medium {{ $class }}">
    <a href="{{ request()->fullUrlWithQuery(['orden' => $column, 'dir' => $next, 'page' => null]) }}" class="inline-flex items-center gap-1 hover:text-slate-900 {{ $active ? 'text-slate-900' : '' }}">
        {{ $label }}
        @if ($active)<x-icon :name="$dir === 'asc' ? 'arrow-up' : 'arrow-down'" class="w-3.5 h-3.5" />@else<x-icon name="sort" class="w-3.5 h-3.5 opacity-30" />@endif
    </a>
</th>
