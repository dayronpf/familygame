<?php

namespace App\Services;

use App\Models\Pack;
use App\Models\Premise;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Convierte el formulario del editor en un borrador de premisa (el mismo formato que content/packs/{pack}/pack.json).
 *
 * El panel edita el texto, el título, la enseñanza, las edades y el orden de las escenas. La puesta en escena de
 * cada escena (fondo, personajes, objetos) y las preguntas interactivas se conservan tal como estaban: una escena
 * nueva copia la puesta en escena de la anterior. La validación completa la hace el motor al publicar (docs/37);
 * aquí se revisa lo que se puede revisar sin él: largos, marcas {…} que existen y edades.
 */
class StoryEditor
{
    public const MIN_SCENES = 3;

    public const MAX_SCENES = 20;

    /**
     * @param  array  $input  title, lesson, value, ages[], in_app, catalog[heroe, generoHeroe, edad, semilla],
     *                        beats[][id, variants[][id, text]]
     * @return array{0: array, 1: ?array} [premisa, entrada del catálogo o null]
     */
    public function build(Premise $premise, array $input): array
    {
        $base = $premise->editable();
        $errors = [];

        $title = trim((string) ($input['title'] ?? ''));
        if (mb_strlen($title) < 3 || mb_strlen($title) > 80) {
            $errors['title'] = 'El título debe tener entre 3 y 80 caracteres.';
        }
        $lesson = trim((string) ($input['lesson'] ?? ''));
        if (mb_strlen($lesson) > 200) {
            $errors['lesson'] = 'La enseñanza puede tener como mucho 200 caracteres.';
        }
        $pack = $premise->pack;
        $morals = collect($pack?->morals ?? [])->pluck('id')->all();
        $value = (string) ($input['value'] ?? '');
        if (! in_array($value, $morals, true)) {
            $errors['value'] = 'Elige una enseñanza del pack.';
        }
        $ages = array_values(array_intersect(Premise::AGES, (array) ($input['ages'] ?? [])));
        if ($ages === []) {
            $errors['ages'] = 'Marca al menos una edad.';
        }

        // Escenas
        $baseBeats = collect($base['beats'] ?? [])->keyBy('id');
        $allowed = $this->allowedTokens($base);
        $beats = [];
        $usedIds = [];
        $prevScene = null;
        foreach (array_values((array) ($input['beats'] ?? [])) as $i => $row) {
            $n = $i + 1;
            $old = isset($row['id']) && $baseBeats->has($row['id']) ? $baseBeats[$row['id']] : null;
            $beatId = $old['id'] ?? $this->uniqueId('escena_'.$n, $usedIds);
            $usedIds[] = $beatId;
            $oldVariants = collect($old['variants'] ?? [])->keyBy('id');
            $template = $old['variants'][0]['scene'] ?? $prevScene;
            $variants = [];
            $variantIds = [];
            foreach (array_values((array) ($row['variants'] ?? [])) as $j => $v) {
                $text = $this->cleanText((string) ($v['text'] ?? ''));
                if ($text === '') {
                    continue; // una variante vacía se quita
                }
                $len = mb_strlen($text);
                if ($len < 10 || $len > 1200) {
                    $errors["beats.$i.variants.$j.text"] = "Escena {$n}: cada texto debe tener entre 10 y 1200 caracteres (tiene {$len}).";
                }
                foreach ($this->tokenProblems($text, $allowed) as $problem) {
                    $errors["beats.$i.variants.$j.tokens"] = "Escena {$n}: {$problem}";
                }
                $oldV = isset($v['id']) && $oldVariants->has($v['id']) ? $oldVariants[$v['id']] : null;
                $variantId = $oldV['id'] ?? $this->uniqueId($base['id'].'_'.$beatId.'_'.chr(97 + $j), $variantIds);
                $variantIds[] = $variantId;
                $variant = $oldV ?? ['id' => $variantId];
                $variant['text'] = $text;
                if (! isset($variant['scene']) && $template !== null) {
                    $variant['scene'] = $template;
                }
                if (isset($row['scene']) && is_array($row['scene'])) {
                    $variant['scene'] = $this->applyStaging($variant['scene'] ?? [], $row['scene'], $base);
                }
                $variants[] = $variant;
            }
            if ($variants === []) {
                $errors["beats.$i"] = "Escena {$n}: escribe el texto de la escena o quítala.";

                continue;
            }
            $beat = $old ?? ['id' => $beatId];
            $beat['variants'] = $variants;
            // «Cambia de lugar»: la escena cuenta que alguien va a otro sitio (el motor lo exige si cambia el fondo).
            if (isset($row['scene']) && is_array($row['scene'])) {
                if (! empty($row['moves'])) {
                    $beat['moves'] = true;
                } elseif (($beat['moves'] ?? null) === true) {
                    unset($beat['moves']);
                }
            }
            $beats[] = $beat;
            $prevScene = $variants[0]['scene'] ?? $prevScene;
        }
        if (count($beats) < self::MIN_SCENES || count($beats) > self::MAX_SCENES) {
            $errors['beats'] = 'Un cuento necesita entre '.self::MIN_SCENES.' y '.self::MAX_SCENES.' escenas.';
        }

        // En la app (catálogo fijo)
        $catalog = null;
        if (! empty($input['in_app'])) {
            $c = (array) ($input['catalog'] ?? []);
            $hero = trim((string) ($c['heroe'] ?? ''));
            if (! preg_match('/^[\p{L}][\p{L} \'-]{1,23}$/u', $hero)) {
                $errors['catalog.heroe'] = 'El nombre del protagonista debe tener solo letras (2 a 24).';
            }
            $gender = in_array($c['generoHeroe'] ?? '', ['f', 'm'], true) ? $c['generoHeroe'] : null;
            if ($gender === null) {
                $errors['catalog.generoHeroe'] = 'Elige si el protagonista es niña o niño.';
            }
            $age = in_array($c['edad'] ?? '', Premise::AGES, true) ? $c['edad'] : null;
            if ($age === null) {
                $errors['catalog.edad'] = 'Elige la edad con la que sale en la app.';
            }
            $seed = filter_var($c['semilla'] ?? 1, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 999999]]);
            if ($seed === false) {
                $errors['catalog.semilla'] = 'La semilla debe ser un número entero positivo.';
            }
            // Se conserva lo que ya tenía la entrada (p. ej. «caracteres», que calcula la publicación).
            $catalog = array_merge((array) ($premise->editableCatalog() ?? []), [
                'id' => $premise->ref,
                'titulo' => $title,
                'edad' => $age,
                'valor' => $value,
                'semilla' => $seed === false ? 1 : $seed,
                'heroe' => $hero,
                'generoHeroe' => $gender,
            ]);
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        $draft = $base;
        $draft['title'] = $title;
        $draft['lesson'] = $lesson;
        $draft['value'] = $value;
        $draft['ages'] = $ages;
        $draft['beats'] = $beats;

        return [$draft, $catalog];
    }

    public const TIMES = ['' => 'Sin indicar', 'amanecer' => 'Amanecer', 'dia' => 'Día', 'atardecer' => 'Atardecer', 'noche' => 'Noche'];

    public const MOODS = ['calm' => 'Tranquila', 'joy' => 'Alegre', 'hope' => 'Esperanza', 'tension' => 'Tensión', 'mystery' => 'Misterio',
        'sad' => 'Triste', 'triumph' => 'Triunfo', 'sleep' => 'Para dormir'];

    public const CLIPS = ['idle' => 'De pie', 'talk' => 'Habla', 'think' => 'Piensa', 'cheer' => 'Celebra', 'laugh' => 'Ríe',
        'offer' => 'Ofrece algo', 'surprised' => 'Sorprendido', 'wonder' => 'Asombrado', 'sad' => 'Triste', 'sit' => 'Sentado',
        'sit_sad' => 'Sentado triste', 'sleep' => 'Duerme', 'yawn' => 'Bosteza', 'clap' => 'Aplaude', 'wave' => 'Saluda',
        'hug' => 'Abraza', 'point' => 'Señala', 'walk' => 'Camina', 'run' => 'Corre', 'sneak' => 'A escondidas',
        'shiver' => 'Tiembla', 'hide' => 'Se esconde', 'scared' => 'Asustado', 'no' => 'Dice que no', 'proud' => 'Orgulloso',
        'climb' => 'Trepa', 'eat' => 'Come', 'jump' => 'Salta', 'swim' => 'Nada', 'row' => 'Rema'];

    /**
     * Lugar, momento, ánimo, quién sale y qué objetos se ven. Lo demás de la escena (offstage, luz, cuerda…) se conserva.
     */
    private function applyStaging(array $scene, array $in, array $premise): array
    {
        $places = $this->places($premise);
        if (isset($in['bg']) && in_array($in['bg'], $places, true)) {
            $scene['bg'] = $in['bg'];
        }
        if (array_key_exists('time', $in)) {
            if ($in['time'] === '' || $in['time'] === null) {
                unset($scene['time']);
            } elseif (array_key_exists($in['time'], self::TIMES)) {
                $scene['time'] = $in['time'];
            }
        }
        if (isset($in['mood']) && array_key_exists($in['mood'], self::MOODS)) {
            $scene['mood'] = $in['mood'];
        }
        if (isset($in['stage']) && is_array($in['stage'])) {
            $chars = $this->characters($premise);
            $old = array_values($scene['stage'] ?? []);
            $stage = [];
            foreach (array_values($in['stage']) as $k => $st) {
                $who = (string) ($st['who'] ?? '');
                if (! isset($chars[$who])) {
                    continue;
                }
                $entry = $chars[$who]['rig'] ? ['rig' => $who] : ['who' => $who];
                $entry['clip'] = array_key_exists($st['clip'] ?? '', self::CLIPS) ? $st['clip'] : 'idle';
                $prev = $old[$k] ?? null;
                $same = $prev !== null && (($prev['who'] ?? $prev['rig'] ?? null) === $who);
                $stage[] = $same ? array_merge($prev, $entry) : $entry;
            }
            // Repartidos a lo ancho si cambió quién sale.
            $n = count($stage);
            foreach ($stage as $k => $entry) {
                if (! isset($entry['x']) || count($old) !== $n) {
                    $stage[$k]['x'] = $n === 1 ? 0.45 : round(0.28 + 0.48 * $k / ($n - 1), 2);
                }
            }
            $scene['stage'] = $stage;
        }
        if (array_key_exists('props', $in)) {
            $wanted = array_values(array_filter((array) $in['props'], fn ($p) => is_string($p) && $p !== ''));
            $byId = collect($scene['props'] ?? [])->keyBy('prop');
            $firstWho = $scene['stage'][0]['who'] ?? $scene['stage'][0]['rig'] ?? null;
            $props = [];
            foreach ($wanted as $prop) {
                $props[] = $byId[$prop] ?? array_filter(['prop' => $prop, 'near' => $firstWho], fn ($v) => $v !== null);
            }
            if ($props === []) {
                unset($scene['props']);
            } else {
                $scene['props'] = $props;
            }
        }

        return $scene;
    }

    /** Lugares que puede usar el cuento: los de su reparto y los que ya usa. */
    public function places(array $premise): array
    {
        $out = [];
        foreach ($premise['cast'] ?? [] as $c) {
            if (($c['kind'] ?? '') === 'place') {
                array_push($out, ...($c['ids'] ?? []));
            }
        }
        foreach ($premise['beats'] ?? [] as $b) {
            foreach ($b['variants'] ?? [] as $v) {
                if (isset($v['scene']['bg'])) {
                    $out[] = $v['scene']['bg'];
                }
            }
        }

        return array_values(array_unique($out));
    }

    /** Personajes que pueden salir: los papeles del reparto ({hero}, {helper}…) y los personajes fijos (npcs). */
    public function characters(array $premise): array
    {
        $out = [];
        foreach ($premise['cast'] ?? [] as $role => $c) {
            if (($c['kind'] ?? '') === 'character') {
                $out[$role] = ['label' => $role === 'hero' ? 'Protagonista' : ucfirst(implode(', ', $c['ids'] ?? [$role])), 'rig' => false];
            }
        }
        foreach ($premise['npcs'] ?? [] as $id => $names) {
            $out[$id] = ['label' => is_array($names) ? ($names[0] ?? $id) : $id, 'rig' => true];
        }
        // Los que ya salen en alguna escena aunque no estén arriba.
        foreach ($premise['beats'] ?? [] as $b) {
            foreach ($b['variants'] ?? [] as $v) {
                foreach ($v['scene']['stage'] ?? [] as $st) {
                    $id = $st['who'] ?? $st['rig'] ?? null;
                    if ($id !== null && ! isset($out[$id])) {
                        $out[$id] = ['label' => ucfirst($id), 'rig' => isset($st['rig'])];
                    }
                }
            }
        }

        return $out;
    }

    /** Copia una premisa como cuento nuevo del panel (mismo reparto y puesta en escena). */
    public function duplicate(Premise $from, string $title, ?Pack $pack = null): Premise
    {
        $pack ??= $from->pack;
        $id = $this->uniqueId(Str::slug(Str::ascii($title), '_') ?: 'cuento', Premise::query()->where('pack_id', $pack->id)->pluck('premise_id')->all());
        $draft = $from->editable();
        $draft['id'] = $id;
        $draft['title'] = $title;
        // Ids de las variantes con el id nuevo, para que no choquen con los del cuento original.
        foreach ($draft['beats'] ?? [] as $b => $beat) {
            foreach ($beat['variants'] ?? [] as $v => $variant) {
                $draft['beats'][$b]['variants'][$v]['id'] = $id.'_'.$beat['id'].'_'.chr(97 + $v);
            }
            if (isset($beat['choice'])) {
                unset($draft['beats'][$b]['choice']); // los cuentos de la app no tienen preguntas
            }
        }
        $catalog = $from->editableCatalog();
        if ($catalog !== null) {
            $catalog['id'] = "{$pack->id}:{$id}";
            $catalog['titulo'] = $title;
            unset($catalog['caracteres']);
        }

        $premise = new Premise([
            'pack_id' => $pack->id,
            'premise_id' => $id,
            'ref' => "{$pack->id}:{$id}",
            'title' => $title,
            'value' => $draft['value'] ?? '',
            'ages' => $draft['ages'] ?? [],
            'beats' => [],
            'beat_count' => count($draft['beats'] ?? []),
            'variant_count' => 0,
            'position' => 9999,
            'pack_version' => $pack->version,
            'in_pack' => false,
            'origin' => 'panel',
            'review_status' => Premise::PENDING,
            'is_free' => false,
        ]);
        $premise->fill([
            'draft' => $draft,
            'draft_catalog' => $catalog,
            'draft_op' => 'guardar',
            'draft_state' => Premise::DRAFT,
            'draft_updated_at' => now(),
        ])->save();

        return $premise;
    }

    /** Las marcas que el cuento puede usar: los papeles de su reparto y las que ya usa. */
    public function allowedTokens(array $premise): array
    {
        $roots = array_merge(['hero'], array_keys($premise['cast'] ?? []), array_keys($premise['npcs'] ?? []));
        foreach ($premise['beats'] ?? [] as $beat) {
            foreach ($beat['variants'] ?? [] as $v) {
                foreach ($this->tokens($v['text'] ?? '') as $t) {
                    $roots[] = explode('.', $t)[0];
                }
            }
        }

        return array_values(array_unique($roots));
    }

    /** Marcas que ya usa el cuento (para la ayuda del editor), p. ej. {hero}, {hero.o}, {item.un}. */
    public function usedTokens(array $premise): array
    {
        $all = [];
        foreach ($premise['beats'] ?? [] as $beat) {
            foreach ($beat['variants'] ?? [] as $v) {
                array_push($all, ...$this->tokens($v['text'] ?? ''));
            }
        }
        $all = array_values(array_unique($all));
        sort($all);

        return $all;
    }

    /** @return list<string> */
    private function tokens(string $text): array
    {
        preg_match_all('/\{([^{}\s]+)\}/u', $text, $m);

        return $m[1];
    }

    /** @return list<string> */
    private function tokenProblems(string $text, array $allowed): array
    {
        $problems = [];
        if (substr_count($text, '{') !== substr_count($text, '}')) {
            $problems[] = 'hay una llave { o } sin cerrar.';
        }
        foreach ($this->tokens($text) as $t) {
            $root = explode('.', $t)[0];
            if (! in_array($root, $allowed, true)) {
                $problems[] = "la marca {{$t}} no existe en este cuento.";
            }
        }

        return $problems;
    }

    private function cleanText(string $text): string
    {
        $text = str_replace(["\r\n", "\r"], "\n", $text);
        $text = preg_replace('/[ \t]+/u', ' ', $text);

        return trim(preg_replace('/\n{3,}/', "\n\n", $text));
    }

    private function uniqueId(string $id, array $taken): string
    {
        $id = substr(preg_replace('/[^a-z0-9_]/', '_', strtolower($id)), 0, 60);
        $candidate = $id;
        for ($i = 2; in_array($candidate, $taken, true); $i++) {
            $candidate = $id.'_'.$i;
        }

        return $candidate;
    }
}
