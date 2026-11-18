@props(['title' => 'No hay nada aquí', 'icon' => 'search'])
<div class="text-center py-12 px-4">
    <div class="mx-auto w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mb-3"><x-icon :name="$icon" class="w-6 h-6" /></div>
    <p class="font-medium text-slate-800">{{ $title }}</p>
    @if (trim($slot))<div class="text-sm text-slate-500 mt-1">{{ $slot }}</div>@endif
    {{ $action ?? '' }}
</div>
