@extends('layouts.admin')
@section('title', 'Nuevo cuento')
@section('content')
<x-page-header title="Nuevo cuento" :back="route('admin.stories.index')" back-label="Cuentos"
    subtitle="Un cuento nuevo parte de uno que ya existe: hereda su mundo, sus personajes y sus dibujos. Después cambias el título, el texto de cada escena y el protagonista." />

<form method="post" action="{{ route('admin.stories.store') }}" class="max-w-3xl space-y-6">
    @csrf
    <x-card title="1. Elige el mundo">
        <div class="grid sm:grid-cols-3 gap-3">
            @foreach ($packs as $p)
                <label class="cursor-pointer">
                    <input type="radio" name="pack" value="{{ $p->id }}" class="peer sr-only" @checked($packId === $p->id) onchange="filterTemplates(this.value)">
                    <span class="block rounded-xl ring-1 ring-slate-200 p-4 peer-checked:ring-2 peer-checked:ring-brand-600 peer-checked:bg-brand-50 hover:bg-slate-50">
                        <span class="block font-medium text-slate-900">{{ $p->name }}</span>
                        <span class="block text-xs text-slate-500 mt-0.5">{{ $templates->where('pack_id', $p->id)->count() }} cuentos</span>
                    </span>
                </label>
            @endforeach
        </div>
    </x-card>

    <x-card title="2. Elige el cuento base" subtitle="Elige uno parecido al que quieres escribir: mismos personajes, misma edad.">
        <div class="relative mb-3">
            <x-icon name="search" class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input type="search" placeholder="Buscar cuento…" class="input pl-9" oninput="searchTemplates(this.value)">
        </div>
        <div class="max-h-80 overflow-y-auto divide-y divide-slate-100 rounded-lg ring-1 ring-slate-200" id="templates">
            @foreach ($templates as $t)
                <label class="flex items-center gap-3 px-4 py-2.5 cursor-pointer hover:bg-slate-50" data-pack="{{ $t->pack_id }}" data-title="{{ mb_strtolower($t->title) }}">
                    <input type="radio" name="template" value="{{ $t->id }}" class="text-brand-600" @checked((string) old('template', $from) === (string) $t->id) required>
                    <span class="flex-1">{{ $t->title }}</span>
                    <span class="text-xs text-slate-500">{{ implode(', ', $t->ages ?? []) }} años</span>
                    @if ($t->catalog)<x-badge color="green">En la app</x-badge>@endif
                </label>
            @endforeach
        </div>
    </x-card>

    <x-card title="3. Ponle título">
        <x-field label="Título del cuento nuevo" name="title">
            <input name="title" value="{{ old('title') }}" maxlength="80" required class="input text-base" placeholder="El faro que no quería dormir">
        </x-field>
    </x-card>

    <div class="flex justify-end gap-2">
        <x-btn variant="ghost" :href="route('admin.stories.index')">Cancelar</x-btn>
        <x-btn variant="primary" icon="plus">Crear y empezar a escribir</x-btn>
    </div>
</form>

@push('scripts')
<script>
    let packFilter = @json($packId), textFilter = '';
    const apply = () => document.querySelectorAll('#templates [data-pack]').forEach(el =>
        el.classList.toggle('hidden', el.dataset.pack !== packFilter || !el.dataset.title.includes(textFilter)));
    window.filterTemplates = p => { packFilter = p; apply(); };
    window.searchTemplates = q => { textFilter = q.toLowerCase(); apply(); };
    apply();
</script>
@endpush
@endsection
