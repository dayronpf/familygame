@props(['label', 'name' => null, 'hint' => null, 'for' => null])
<label {{ $attributes->merge(['class' => 'block']) }} @if ($for) for="{{ $for }}" @endif>
    <span class="block text-sm font-medium text-slate-700 mb-1">{{ $label }}</span>
    {{ $slot }}
    @if ($name && $errors->has($name))<span class="block text-xs text-rose-600 mt-1">{{ $errors->first($name) }}</span>
    @elseif ($hint)<span class="block text-xs text-slate-500 mt-1">{{ $hint }}</span>@endif
</label>
