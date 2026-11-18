@props(['label', 'value', 'hint' => null, 'href' => null, 'icon' => null, 'tone' => 'slate'])
@php($tones = ['slate' => 'text-slate-500 bg-slate-100', 'green' => 'text-emerald-600 bg-emerald-50', 'amber' => 'text-amber-600 bg-amber-50', 'indigo' => 'text-brand-600 bg-brand-50', 'violet' => 'text-violet-600 bg-violet-50', 'blue' => 'text-sky-600 bg-sky-50'])
<{{ $href ? 'a' : 'div' }} @if ($href) href="{{ $href }}" @endif class="block bg-white rounded-xl border border-slate-200 shadow-sm p-4 {{ $href ? 'hover:border-brand-300 hover:shadow transition' : '' }}">
    <div class="flex items-center gap-2">
        @if ($icon)<span class="rounded-lg p-1.5 {{ $tones[$tone] ?? $tones['slate'] }}"><x-icon :name="$icon" class="w-4 h-4" /></span>@endif
        <span class="text-sm text-slate-600">{{ $label }}</span>
    </div>
    <div class="text-3xl font-semibold text-slate-900 mt-2 tabular-nums">{{ $value }}</div>
    @if ($hint)<div class="text-xs text-slate-500 mt-1">{{ $hint }}</div>@endif
</{{ $href ? 'a' : 'div' }}>
