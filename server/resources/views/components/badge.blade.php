@props(['color' => 'slate', 'dot' => false])
@php($colors = [
    'slate' => 'bg-slate-100 text-slate-700 ring-slate-200', 'green' => 'bg-emerald-50 text-emerald-700 ring-emerald-200',
    'amber' => 'bg-amber-50 text-amber-800 ring-amber-200', 'red' => 'bg-rose-50 text-rose-700 ring-rose-200',
    'blue' => 'bg-sky-50 text-sky-700 ring-sky-200', 'violet' => 'bg-violet-50 text-violet-700 ring-violet-200',
    'indigo' => 'bg-brand-50 text-brand-700 ring-brand-200',
])
@php($dots = ['slate' => 'bg-slate-400', 'green' => 'bg-emerald-500', 'amber' => 'bg-amber-500', 'red' => 'bg-rose-500', 'blue' => 'bg-sky-500', 'violet' => 'bg-violet-500', 'indigo' => 'bg-brand-500'])
<span {{ $attributes->merge(['class' => 'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset whitespace-nowrap '.($colors[$color] ?? $colors['slate'])]) }}>@if ($dot)<span class="w-1.5 h-1.5 rounded-full {{ $dots[$color] ?? $dots['slate'] }}"></span>@endif{{ $slot }}</span>
