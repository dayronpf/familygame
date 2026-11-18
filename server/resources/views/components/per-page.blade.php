@props(['value', 'options' => [25, 50, 100]])
<label class="inline-flex items-center gap-2 text-sm text-slate-600">Mostrar
    <select onchange="location.href=this.value" class="input py-1 w-auto">
        @foreach ($options as $n)<option value="{{ request()->fullUrlWithQuery(['por_pagina' => $n, 'page' => null]) }}" @selected((int) $value === $n)>{{ $n }}</option>@endforeach
    </select>
</label>
