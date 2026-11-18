<div data-stage-row class="flex items-center gap-2">
    <select data-field="scene.stage.#.who" class="input py-1.5 flex-1">
        @foreach ($staging['characters'] as $id => $c)<option value="{{ $id }}" @selected($who === $id)>{{ $c['label'] }}</option>@endforeach
    </select>
    <select data-field="scene.stage.#.clip" class="input py-1.5 flex-1">
        @foreach ($staging['clips'] as $id => $label)<option value="{{ $id }}" @selected($clip === $id)>{{ $label }}</option>@endforeach
    </select>
    <button type="button" data-remove-stage class="p-1.5 rounded-md text-slate-400 hover:bg-rose-50 hover:text-rose-700" title="Quitar"><x-icon name="x" class="w-4 h-4" /></button>
</div>
