@php($sc = $beat['scene'] ?? [])
<li class="rounded-xl border border-slate-200 bg-slate-50/50">
    <div class="flex items-center gap-2 px-4 py-2 border-b border-slate-200">
        <span class="w-6 h-6 rounded-full bg-brand-600 text-white text-xs font-semibold flex items-center justify-center" data-n>{{ $n }}</span>
        <span class="text-sm font-medium text-slate-700">Escena</span>
        <input type="hidden" data-beat-id value="{{ $beat['id'] ?? '' }}">
        <div class="ml-auto flex items-center gap-1">
            <button type="button" data-up class="p-1.5 rounded-md text-slate-500 hover:bg-white hover:text-slate-800 disabled:opacity-30" title="Subir"><x-icon name="arrow-up" class="w-4 h-4" /></button>
            <button type="button" data-down class="p-1.5 rounded-md text-slate-500 hover:bg-white hover:text-slate-800 disabled:opacity-30" title="Bajar"><x-icon name="arrow-down" class="w-4 h-4" /></button>
            <button type="button" data-insert-after class="p-1.5 rounded-md text-slate-500 hover:bg-white hover:text-slate-800" title="Insertar una escena después"><x-icon name="plus" class="w-4 h-4" /></button>
            <button type="button" data-remove-scene class="p-1.5 rounded-md text-slate-500 hover:bg-rose-50 hover:text-rose-700" title="Quitar escena"><x-icon name="trash" class="w-4 h-4" /></button>
        </div>
    </div>
    <div class="p-4 space-y-3" data-variants>
        @foreach ($beat['variants'] ?? [] as $vi => $variant)
            @include('admin.stories._variant', ['variant' => $variant, 'vi' => $vi])
        @endforeach
    </div>
    <div class="px-4 pb-3">
        <button type="button" data-add-variant class="text-xs font-medium text-brand-700 hover:underline inline-flex items-center gap-1"><x-icon name="plus" class="w-3.5 h-3.5" />Escribir otra versión de esta escena</button>
    </div>
    <details data-staging class="border-t border-slate-200 px-4 py-3">
        <summary class="cursor-pointer text-sm text-slate-600 hover:text-slate-900 flex items-center gap-2">
            <span class="font-medium">Dibujo de la escena:</span> <span data-staging-summary class="text-slate-500"></span>
        </summary>
        <div class="grid sm:grid-cols-3 gap-3 mt-3">
            <x-field label="Lugar">
                <select data-field="scene.bg" class="input py-1.5">
                    @foreach ($staging['places'] as $place)<option value="{{ $place }}" @selected(($sc['bg'] ?? '') === $place)>{{ ucfirst(str_replace('_', ' ', $place)) }}</option>@endforeach
                </select>
            </x-field>
            <x-field label="Momento del día">
                <select data-field="scene.time" class="input py-1.5">
                    @foreach ($staging['times'] as $v => $label)<option value="{{ $v }}" @selected(($sc['time'] ?? '') === $v)>{{ $label }}</option>@endforeach
                </select>
            </x-field>
            <x-field label="Ambiente">
                <select data-field="scene.mood" class="input py-1.5">
                    @foreach ($staging['moods'] as $v => $label)<option value="{{ $v }}" @selected(($sc['mood'] ?? 'calm') === $v)>{{ $label }}</option>@endforeach
                </select>
            </x-field>
        </div>
        <label class="mt-3 flex items-start gap-2 text-sm cursor-pointer">
            <input type="checkbox" data-field="moves" value="1" class="mt-0.5 rounded border-slate-300 text-brand-600" @checked(! empty($beat['moves']))>
            <span><span class="font-medium text-slate-700">Cambia de lugar</span> <span class="text-slate-500">— el texto cuenta que van a otro sitio (si el lugar es distinto al de la escena anterior, hace falta).</span></span>
        </label>
        <div class="mt-3">
            <span class="block text-sm font-medium text-slate-700 mb-1">Quién sale y qué hace</span>
            <div data-stage class="space-y-2">
                @foreach ($sc['stage'] ?? [] as $st)
                    @include('admin.stories._stage_row', ['who' => $st['who'] ?? $st['rig'] ?? '', 'clip' => $st['clip'] ?? 'idle', 'staging' => $staging])
                @endforeach
            </div>
            <button type="button" data-add-stage class="mt-2 text-xs font-medium text-brand-700 hover:underline inline-flex items-center gap-1"><x-icon name="plus" class="w-3.5 h-3.5" />Agregar personaje</button>
        </div>
        @if ($staging['props'])
            <div class="mt-3">
                <span class="block text-sm font-medium text-slate-700 mb-1">Objetos que se ven</span>
                <input type="hidden" data-field="scene.props.[]" value="">
                <div class="flex flex-wrap gap-1.5">
                    @php($has = collect($sc['props'] ?? [])->map(fn ($x) => is_array($x) ? ($x['prop'] ?? null) : $x)->filter()->all())
                    @foreach ($staging['props'] as $prop)
                        <label class="cursor-pointer">
                            <input type="checkbox" data-field="scene.props.[]" value="{{ $prop }}" class="peer sr-only" @checked(in_array($prop, $has, true))>
                            <span class="inline-block rounded-md px-2 py-1 text-xs ring-1 ring-slate-300 text-slate-600 peer-checked:bg-amber-100 peer-checked:text-amber-900 peer-checked:ring-amber-300">{{ str_replace('_', ' ', $prop) }}</span>
                        </label>
                    @endforeach
                </div>
            </div>
        @endif
    </details>
</li>
