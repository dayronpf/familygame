@extends('layouts.admin')
@section('title', 'Editar · '.($story['title'] ?? $premise->title))
@section('content')
@php($inApp = old('in_app', $catalog !== null ? '1' : null))
@php($cat = old('catalog', $catalog ?? []))
@php($beatsInput = old('beats'))
@php($beats = $beatsInput ?? collect($story['beats'] ?? [])->map(fn ($b) => ['id' => $b['id'], 'moves' => $b['moves'] ?? false, 'scene' => $b['variants'][0]['scene'] ?? [], 'variants' => collect($b['variants'] ?? [])->map(fn ($v) => ['id' => $v['id'], 'text' => $v['text'] ?? ''])->all()])->all())

<form method="post" action="{{ route('admin.stories.update', $premise) }}" id="editor">
@csrf @method('PUT')

<x-page-header :title="$premise->isUnpublished() ? 'Cuento nuevo' : 'Editar cuento'" :back="route('admin.stories.show', $premise)" back-label="Volver al cuento">
    <x-slot:meta>
        <p class="text-sm text-slate-500 mt-1">{{ $premise->pack?->name }} · <span class="font-mono text-xs">{{ $premise->ref }}</span>
            @if ($premise->hasDraft()) · <x-badge color="indigo">Borrador del {{ $premise->draft_updated_at?->format('d/m H:i') }}</x-badge>@endif</p>
    </x-slot:meta>
    <x-slot:actions>
        <x-btn variant="secondary" name="accion" value="guardar" icon="check">Guardar borrador</x-btn>
        <x-btn variant="primary" name="accion" value="publicar" icon="send" data-confirm-tone="primary" data-confirm-title="Guardar y publicar"
            data-confirm="Se guardan los cambios y el cuento pasa a la cola de publicación. La app lo recibirá cuando termine." data-confirm-ok="Publicar">Guardar y publicar</x-btn>
    </x-slot:actions>
</x-page-header>

<div class="grid lg:grid-cols-3 gap-6 items-start">
    <div class="lg:col-span-2 space-y-6 min-w-0">
        <x-card title="Datos del cuento">
            <div class="grid sm:grid-cols-2 gap-4">
                <x-field label="Título" name="title" class="sm:col-span-2">
                    <input name="title" value="{{ old('title', $story['title'] ?? '') }}" maxlength="80" required class="input text-base font-medium">
                </x-field>
                <x-field label="Enseñanza" name="value">
                    <select name="value" class="input" required>
                        @foreach ($premise->pack?->morals ?? [] as $m)
                            <option value="{{ $m['id'] }}" @selected(old('value', $story['value'] ?? '') === $m['id'])>{{ $m['name'] }}</option>
                        @endforeach
                    </select>
                </x-field>
                <x-field label="Edades" name="ages">
                    <div class="flex flex-wrap gap-2">
                        @foreach ($ages as $a)
                            <label class="cursor-pointer">
                                <input type="checkbox" name="ages[]" value="{{ $a }}" class="peer sr-only" @checked(in_array($a, old('ages', $story['ages'] ?? []), true))>
                                <span class="inline-block rounded-lg px-3 py-1.5 text-sm ring-1 ring-slate-300 text-slate-600 peer-checked:bg-brand-600 peer-checked:text-white peer-checked:ring-brand-600 peer-focus-visible:ring-2">{{ $a }} años</span>
                            </label>
                        @endforeach
                    </div>
                </x-field>
                <x-field label="La enseñanza en una frase" name="lesson" hint="La dice la app al final del cuento. Corta y en positivo." class="sm:col-span-2">
                    <textarea name="lesson" rows="2" maxlength="200" class="input resize-none" placeholder="Devolver lo que es de otro hace amigos.">{{ old('lesson', $story['lesson'] ?? '') }}</textarea>
                </x-field>
            </div>
        </x-card>

        <x-card title="En la app" subtitle="Cómo aparece el cuento en el catálogo de la app.">
            <label class="flex items-start gap-3 cursor-pointer">
                <input type="checkbox" name="in_app" value="1" class="mt-1 rounded border-slate-300 text-brand-600" @checked($inApp) onchange="document.getElementById('app-fields').classList.toggle('hidden', !this.checked)">
                <span><span class="font-medium text-slate-800">Mostrar este cuento en la app</span>
                    <span class="block text-sm text-slate-500">Si no lo marcas, el cuento queda en el pack pero las familias no lo ven.</span></span>
            </label>
            <div id="app-fields" class="grid sm:grid-cols-3 gap-4 mt-4 {{ $inApp ? '' : 'hidden' }}">
                <x-field label="Nombre del protagonista" name="catalog.heroe">
                    <input name="catalog[heroe]" value="{{ $cat['heroe'] ?? '' }}" maxlength="24" class="input" placeholder="Mara">
                </x-field>
                <x-field label="Es…" name="catalog.generoHeroe">
                    <select name="catalog[generoHeroe]" class="input">
                        <option value="f" @selected(($cat['generoHeroe'] ?? '') === 'f')>Niña</option>
                        <option value="m" @selected(($cat['generoHeroe'] ?? '') === 'm')>Niño</option>
                    </select>
                </x-field>
                <x-field label="Edad en la app" name="catalog.edad">
                    <select name="catalog[edad]" class="input">
                        @foreach ($ages as $a)<option value="{{ $a }}" @selected(($cat['edad'] ?? '') === $a)>{{ $a }} años</option>@endforeach
                    </select>
                </x-field>
                <details class="sm:col-span-3 text-sm">
                    <summary class="cursor-pointer text-slate-500 hover:text-slate-700">Avanzado</summary>
                    <div class="mt-3 max-w-xs">
                        <x-field label="Semilla" name="catalog.semilla" hint="Número que fija qué versión de cada escena usa la app. Cambiarlo cambia el cuento que se oye.">
                            <input type="number" min="1" name="catalog[semilla]" value="{{ $cat['semilla'] ?? 1 }}" class="input">
                        </x-field>
                    </div>
                </details>
            </div>
        </x-card>

        <x-card title="Escenas" subtitle="Cada escena es una página del cuento con su dibujo. Puedes cambiar el orden, agregar o quitar escenas y escribir otra versión de una escena.">
            <x-slot:actions><span class="text-sm text-slate-500"><span id="scene-count">0</span> escenas · <span id="char-count">0</span> caracteres</span></x-slot:actions>
            <ol id="scenes" class="space-y-4">
                @foreach ($beats as $i => $beat)
                    @include('admin.stories._scene', ['beat' => $beat, 'n' => $i + 1, 'staging' => $staging])
                @endforeach
            </ol>
            <button type="button" onclick="addScene()" class="mt-4 w-full rounded-xl border-2 border-dashed border-slate-300 py-3 text-sm font-medium text-slate-600 hover:border-brand-400 hover:text-brand-700 inline-flex items-center justify-center gap-2">
                <x-icon name="plus" class="w-4 h-4" />Agregar escena al final
            </button>
            <p class="text-xs text-slate-500 mt-3">Una escena nueva empieza con el dibujo de la anterior: ábrelo en «Dibujo de la escena» y elige el lugar, el momento y quién sale, para que el dibujo cuente lo mismo que el texto. Al publicar, el motor revisa que coincidan.</p>
        </x-card>

        <div class="flex flex-wrap justify-end gap-2">
            <x-btn variant="ghost" :href="route('admin.stories.show', $premise)">Cancelar</x-btn>
            <x-btn variant="secondary" name="accion" value="guardar" icon="check">Guardar borrador</x-btn>
            <x-btn variant="primary" name="accion" value="publicar" icon="send">Guardar y publicar</x-btn>
        </div>
    </div>

    <aside class="space-y-4 lg:sticky lg:top-6">
        <x-card title="Marcas" subtitle="Toca una para insertarla donde está el cursor.">
            @if ($tokens)
                <div class="flex flex-wrap gap-1.5">
                    @foreach ($tokens as $t)
                        <button type="button" data-token="{{ '{'.$t.'}' }}" class="rounded-md bg-violet-50 text-violet-700 ring-1 ring-violet-200 px-2 py-1 text-xs font-mono hover:bg-violet-100">{{ '{'.$t.'}' }}</button>
                    @endforeach
                </div>
            @else
                <p class="text-sm text-slate-500">Este cuento no usa marcas.</p>
            @endif
            <dl class="mt-4 text-xs text-slate-600 space-y-1.5">
                <div><dt class="inline font-mono text-violet-700">{hero}</dt> <dd class="inline">el nombre del protagonista</dd></div>
                <div><dt class="inline font-mono text-violet-700">{hero.o}</dt> <dd class="inline">«o» o «a» según sea niño o niña (content{hero.o})</dd></div>
                <div><dt class="inline font-mono text-violet-700">{item.un}</dt> <dd class="inline">el objeto con su artículo («una caracola»)</dd></div>
            </dl>
        </x-card>

        @if ($cast)
            <x-card title="Reparto" subtitle="Quién es quién en este cuento. Toca para insertar.">
                <ul class="text-sm space-y-1.5">
                    @foreach ($cast as $role => $c)
                        <li class="flex justify-between gap-2"><button type="button" data-token="{{ '{'.$role.'}' }}" class="font-mono text-violet-700 hover:underline">{{ '{'.$role.'}' }}</button>
                            <span class="text-slate-600 text-right">{{ $role === 'hero' ? 'protagonista' : implode(', ', $c['ids'] ?? $c['roles'] ?? []) }}</span></li>
                    @endforeach
                </ul>
            </x-card>
        @endif

        <x-card title="Para que suene bien">
            <ul class="text-sm text-slate-600 space-y-2 list-disc ml-4">
                <li>Frases cortas, para leer en voz alta y con calma.</li>
                <li>Español neutro de Latinoamérica: sin «vosotros».</li>
                <li>Entre 3 y 12 escenas; cada una de 10 a 1200 caracteres.</li>
                <li>Si cambias el texto, la voz grabada se vuelve a grabar al publicar; mientras tanto, lo lee la voz del teléfono.</li>
            </ul>
        </x-card>
    </aside>
</div>
</form>

<template id="tpl-stage-row">@include('admin.stories._stage_row', ['who' => '', 'clip' => 'idle', 'staging' => $staging])</template>
<template id="tpl-variant">@include('admin.stories._variant', ['variant' => ['id' => '', 'text' => ''], 'vi' => 1])</template>

@push('scripts')
<script>
(() => {
    const form = document.getElementById('editor');
    const scenes = document.getElementById('scenes');
    let lastField = null, dirty = false;

    // Los nombres de los campos se arman al enviar, en el orden en que se ven.
    const renumber = () => {
        let chars = 0;
        [...scenes.children].forEach((li, i) => {
            li.querySelector('[data-n]').textContent = i + 1;
            li.querySelector('[data-beat-id]').name = `beats[${i}][id]`;
            li.querySelector('[data-up]').disabled = i === 0;
            li.querySelector('[data-down]').disabled = i === scenes.children.length - 1;
            li.querySelectorAll('[data-field]').forEach(el => {
                const row = el.closest('[data-stage-row]');
                const k = row ? [...row.parentElement.children].indexOf(row) : 0;
                el.name = `beats[${i}]` + el.dataset.field.split('.').map(p => p === '#' ? `[${k}]` : p === '[]' ? '[]' : `[${p}]`).join('');
            });
            const sum = li.querySelector('[data-staging-summary]');
            if (sum) {
                const bg = li.querySelector('[data-field="scene.bg"]'), tm = li.querySelector('[data-field="scene.time"]');
                const who = [...li.querySelectorAll('[data-field="scene.stage.#.who"]')].map(s => s.options[s.selectedIndex]?.text).filter(Boolean);
                sum.textContent = [bg?.options[bg.selectedIndex]?.text, tm?.value ? tm.options[tm.selectedIndex].text : null, who.join(', ') || 'nadie'].filter(Boolean).join(' · ');
            }
            [...li.querySelectorAll('[data-variant]')].forEach((v, j) => {
                v.querySelector('[data-variant-id]').name = `beats[${i}][variants][${j}][id]`;
                v.querySelector('textarea').name = `beats[${i}][variants][${j}][text]`;
                v.querySelector('[data-variant-label]').textContent = li.querySelectorAll('[data-variant]').length > 1 ? `Versión ${String.fromCharCode(65 + j)}` : '';
                v.querySelector('[data-remove-variant]').classList.toggle('hidden', li.querySelectorAll('[data-variant]').length < 2);
                chars += v.querySelector('textarea').value.length;
            });
        });
        document.getElementById('scene-count').textContent = scenes.children.length;
        document.getElementById('char-count').textContent = chars.toLocaleString('es');
    };
    const count = ta => {
        const n = ta.value.length, el = ta.closest('[data-variant]').querySelector('[data-count]');
        el.textContent = `${n} / 1200`;
        el.className = 'text-xs tabular-nums ' + (n > 1200 || (n > 0 && n < 10) ? 'text-rose-600 font-medium' : 'text-slate-400');
    };
    const autosize = ta => { ta.style.height = 'auto'; ta.style.height = (ta.scrollHeight + 2) + 'px'; };

    // Una escena nueva copia la anterior (su dibujo) con el texto vacío y sin ids.
    window.addScene = (after = null) => {
        const from = after || scenes.lastElementChild;
        const node = from.cloneNode(true);
        from.querySelectorAll('select').forEach((s, k) => node.querySelectorAll('select')[k].value = s.value);
        node.querySelector('[data-beat-id]').value = '';
        node.querySelectorAll('[data-variant]').forEach((v, k) => k > 0 ? v.remove() : null);
        const v = node.querySelector('[data-variant]');
        v.querySelector('[data-variant-id]').value = '';
        v.querySelector('textarea').value = '';
        node.querySelector('details[data-staging]')?.setAttribute('open', '');
        after ? after.after(node) : scenes.append(node);
        dirty = true; renumber();
        count(v.querySelector('textarea'));
        v.querySelector('textarea').focus();
    };
    scenes.addEventListener('click', e => {
        const li = e.target.closest('#scenes > li');
        if (!li) return;
        if (e.target.closest('[data-up]')) { li.previousElementSibling?.before(li); }
        else if (e.target.closest('[data-down]')) { li.nextElementSibling?.after(li); }
        else if (e.target.closest('[data-insert-after]')) { addScene(li); return; }
        else if (e.target.closest('[data-remove-scene]')) {
            if (scenes.children.length <= 3) { alert('Un cuento necesita al menos 3 escenas.'); return; }
            if (!confirm('¿Quitar esta escena?')) return;
            li.remove();
        } else if (e.target.closest('[data-add-variant]')) {
            const v = document.getElementById('tpl-variant').content.firstElementChild.cloneNode(true);
            li.querySelector('[data-variants]').append(v);
            v.querySelector('textarea').focus();
        } else if (e.target.closest('[data-remove-variant]')) {
            e.target.closest('[data-variant]').remove();
        } else if (e.target.closest('[data-add-stage]')) {
            li.querySelector('[data-stage]').append(document.getElementById('tpl-stage-row').content.firstElementChild.cloneNode(true));
        } else if (e.target.closest('[data-remove-stage]')) {
            e.target.closest('[data-stage-row]').remove();
        } else return;
        dirty = true; renumber();
    });
    scenes.addEventListener('input', e => { if (e.target.matches('textarea')) { count(e.target); autosize(e.target); dirty = true; renumber(); } });
    scenes.addEventListener('focusin', e => { if (e.target.matches('textarea')) lastField = e.target; });
    form.addEventListener('input', () => dirty = true);
    scenes.addEventListener('change', e => { if (e.target.matches('select, input[type=checkbox]')) { dirty = true; renumber(); } });

    // Marcas: se insertan donde está el cursor.
    document.querySelectorAll('[data-token]').forEach(b => b.addEventListener('click', () => {
        const ta = lastField || scenes.querySelector('textarea');
        if (!ta) return;
        const s = ta.selectionStart ?? ta.value.length, t = b.dataset.token;
        ta.value = ta.value.slice(0, s) + t + ta.value.slice(ta.selectionEnd ?? s);
        ta.focus(); ta.selectionStart = ta.selectionEnd = s + t.length;
        count(ta); dirty = true;
    }));

    form.addEventListener('submit', () => { renumber(); dirty = false; });
    window.addEventListener('beforeunload', e => { if (dirty) { e.preventDefault(); e.returnValue = ''; } });
    scenes.querySelectorAll('textarea').forEach(ta => { count(ta); autosize(ta); });
    renumber();
})();
</script>
@endpush
@endsection
