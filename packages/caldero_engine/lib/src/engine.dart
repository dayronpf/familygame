import 'age.dart';
import 'grammar.dart';
import 'models.dart';
import 'names.dart';
import 'recipe.dart';
import 'rng.dart';

/// No se pudo armar un cuento con el pack y las opciones dadas.
class StoryGenerationException implements Exception {
  StoryGenerationException(this.message);

  final String message;

  @override
  String toString() => 'StoryGenerationException: $message';
}

class StoryOptions {
  const StoryOptions({
    required this.seed,
    this.valueId,
    this.age,
    this.heroName,
    this.heroGender,
    this.choices = const [],
    this.interactive = true,
  });

  /// Opciones ya elegidas (ids de opción), en orden de aparición. Las que falten las elige el motor con una
  /// semilla aparte, así que [StoryEngine.generate] siempre devuelve un cuento completo y determinista.
  final List<String> choices;

  /// `false` = no preguntar nunca (perfil 2–3, ajuste «nunca», temporizador de sueño, cuento guardado): lo que
  /// falte se elige solo. Con `true`, [StoryEngine.begin] se detiene en la primera pregunta sin responder.
  final bool interactive;

  /// Misma semilla + mismo pack + mismas opciones ⇒ mismo cuento.
  final int seed;

  /// Enseñanza deseada; si es `null` se elige una al azar.
  final String? valueId;

  /// Perfil de edad (`2-3`, `4-5`, `6-8`, `9-12`) o `null` para cualquiera. Si el pack no tiene cuentos de esa
  /// edad se usan los del perfil más cercano (ver `Pack.resolveAge`).
  final String? age;

  /// Nombre del niño que escucha el cuento: el héroe lo lleva en el texto y en la voz (nunca viaja en la receta).
  final String? heroName;

  /// `m` o `f`: elige un héroe de ese género (el dibujo y la gramática siguen al héroe elegido). `null` = al azar.
  final String? heroGender;
}

/// El «caldero»: elige enseñanza, reparto y fragmentos coherentes.
class StoryEngine {
  const StoryEngine(this.pack);

  final Pack pack;

  /// Opción que elige la app cuando no pregunta o el niño no contesta. Usa una secuencia aleatoria **aparte** de la
  /// del cuento (semilla + nº de elección): elegir solo no cambia nada de lo contado antes ni de las variantes
  /// que salgan después.
  String _autoChoice(StoryChoice c, int seed, int index) {
    final r = Mulberry32((seed + 0x9E3779B9 * (index + 1)) & 0xFFFFFFFF);
    return c.options[r.nextInt(c.options.length)].id;
  }

  /// Un cuento completo. Si el cuento tiene preguntas y no se dieron todas las [StoryOptions.choices], las que
  /// falten se eligen solas (y la receta lo marca con `auto`).
  Story generate(StoryOptions options) => begin(options).toStory();

  /// Empieza un cuento: se detiene en la primera pregunta sin responder (solo si [StoryOptions.interactive]).
  StoryRun begin(StoryOptions options) => _begin(options, [
        for (final c in options.choices) _Pick(c, auto: false),
      ]);

  StoryRun _begin(StoryOptions options, List<_Pick> picks) {
    final rng = Mulberry32(options.seed);

    final Moral moral;
    if (options.valueId == null) {
      // «Sorpréndeme»: solo entre las enseñanzas que tienen cuentos (en un pack completo, todas)
      final told = pack.moralsWithStories;
      moral = rng.choice(told.isEmpty ? pack.morals : told);
    } else {
      moral = pack.moralById(options.valueId!) ??
          (throw StoryGenerationException(
            'enseñanza desconocida: ${options.valueId}',
          ));
    }

    var premises = pack.premises
        .where((p) => p.fitsValue(moral.id))
        .toList(growable: false);
    final heroName = normalizeChildName(options.heroName);
    final heroGender = options.heroGender;
    if (heroGender != null) {
      // Con el nombre del niño el héroe no puede cambiar de género («Lucía estaba contento»): mejor otro cuento
      final byGender = premises
          .where((p) => heroCanBe(pack, p, heroGender))
          .toList(growable: false);
      if (byGender.isEmpty && heroName != null && premises.isNotEmpty) {
        throw StoryGenerationException(
          'ningún cuento de «${moral.id}» tiene héroe de género $heroGender',
        );
      }
      if (byGender.isNotEmpty) premises = byGender;
    }
    final age = pack.resolveAge(options.age);
    final byAge = premises.where((p) => p.fitsAge(age)).toList(growable: false);
    // Si ninguno de esta enseñanza sirve a esa edad, mejor uno que ninguno
    if (byAge.isNotEmpty) premises = byAge;
    if (premises.isNotEmpty) {
      return _generateFromPremise(
        this,
        options,
        picks,
        pack,
        options.seed,
        moral,
        _pickWeighted(premises, (p) => p.weight, rng),
        rng,
        age: age,
        moralText: moral.textFor(age),
        heroName: heroName,
        heroGender: heroGender,
      );
    }

    final cast = _personalize(
      castStory(pack, rng, heroGender: heroGender, strict: heroName != null),
      heroName,
    );
    final state = <String>{};
    final used = <String>{};
    final scenes = <StoryScene>[];

    for (final stage in storyStages) {
      final fragment = pickFragment(pack, stage, moral.id, state, used, rng);
      used.add(fragment.id);
      state.addAll(fragment.adds);
      scenes.add(
        StoryScene(
          fragmentId: fragment.id,
          text: renderTemplate(fragment.text, cast),
          directives: fragment.scene,
        ),
      );
    }
    return StoryRun._(
      Story(
        seed: options.seed,
        moral: moral,
        cast: cast,
        scenes: scenes,
        recipe: StoryRecipe(
          packId: pack.id,
          packVersion: pack.version,
          engineVersion: engineVersion,
          seed: options.seed,
          valueId: moral.id,
          cast: {for (final e in cast.entries) e.key: e.value.id},
          fragmentIds: [for (final s in scenes) s.fragmentId],
        ),
      ),
      null,
      this,
      options,
      picks,
    );
  }
}

class _Pick {
  const _Pick(this.optionId, {required this.auto});

  final String optionId;
  final bool auto;
}

/// Un cuento a medias: lo ya contado y, si toca, la pregunta pendiente. Inmutable.
///
/// No guarda estado: [choose] vuelve a generar el cuento desde la semilla con una elección más. Las escenas
/// anteriores a la pregunta no dependen de la respuesta, así que salen idénticas.
class StoryRun {
  StoryRun._(
    this.story,
    this.pending,
    this._engine,
    this._options,
    this._picks,
  );

  /// Lo contado hasta ahora. Completo si [pending] es `null`.
  final Story story;

  /// La pregunta sin responder (la última escena de [story] la lleva).
  final StoryChoice? pending;
  final StoryEngine _engine;
  final StoryOptions _options;
  final List<_Pick> _picks;

  bool get isComplete => pending == null;

  /// Sigue el cuento con la opción [optionId]. [auto] marca que la eligió la app y no el niño.
  StoryRun choose(String optionId, {bool auto = false}) {
    final p = pending;
    if (p == null) {
      throw StateError('el cuento no tiene ninguna pregunta pendiente');
    }
    if (p.optionById(optionId) == null) {
      throw ArgumentError.value(
        optionId,
        'optionId',
        'no es una opción de «${p.id}»',
      );
    }
    return _engine._begin(_options, [..._picks, _Pick(optionId, auto: auto)]);
  }

  /// El cuento completo; si falta alguna elección, se hacen solas.
  Story toStory() {
    var run = this;
    while (!run.isComplete) {
      // Misma opción que habría salido con `interactive: false`
      run = run.choose(run.autoOption, auto: true);
    }
    return run.story;
  }

  /// La opción que elegiría la app por su cuenta (la misma que saldría con `interactive: false`).
  String get autoOption =>
      _engine._autoChoice(pending!, _options.seed, _picks.length);
}

/// Cuenta una [premise]: elige el reparto que cumple sus requisitos y, escena a escena, una
/// variante compatible con él y con lo ya contado.
StoryRun _generateFromPremise(
  StoryEngine engine,
  StoryOptions options,
  List<_Pick> picks,
  Pack pack,
  int seed,
  Moral moral,
  Premise premise,
  Mulberry32 rng, {
  String? age,
  String? moralText,
  String? heroName,
  String? heroGender,
}) {
  final cast = _personalize(
    castPremise(pack, premise, rng, heroGender: heroGender, heroName: heroName),
    heroName,
  );
  final state = castState(cast, premise);
  final scenes = <StoryScene>[];
  // Atributos con varias formas: cada uso de `rol.atributo` toma la siguiente, empezando por una al
  // azar, para que un gesto no se repita dentro del mismo cuento.
  final starts = <String, int>{};
  final uses = <String, int>{};
  String choose(String key, List<String> options) {
    final start = starts[key] ??= rng.nextInt(options.length);
    final k = uses[key] = (uses[key] ?? -1) + 1;
    return options[(start + k) % options.length];
  }

  final chosen = <ChosenOption>[];
  final says = <String, String>{};
  StoryChoice? pending;

  for (final beat in premise.beats) {
    final candidates = beat.variants
        .where((v) => v.weight > 0 && state.containsAll(v.requires))
        .toList();
    if (candidates.isEmpty) {
      throw StoryGenerationException(
        'sin variante para ${premise.id}.${beat.id} estado=${(state.toList()..sort())}',
      );
    }
    final variant = _pickWeighted(candidates, (v) => v.weight, rng);
    state.addAll(variant.adds);
    final text = renderTemplate(
      variant.text,
      cast,
      choose: choose,
      alt: rng.nextInt,
      says: says,
    );
    final question = beat.choice;
    if (question == null) {
      scenes.add(
        StoryScene(
          fragmentId: variant.id,
          text: text,
          directives: variant.scene,
        ),
      );
      continue;
    }

    // Una pregunta: se cuenta la escena y luego se elige. La elección **no consume** `rng` (la automática usa una
    // secuencia propia), así que las escenas siguientes no cambian por haber preguntado o no.
    final rendered = _renderChoice(question, cast);
    final index = chosen.length;
    String? optionId;
    var auto = false;
    if (index < picks.length) {
      optionId = picks[index].optionId;
      auto = picks[index].auto;
      if (question.optionById(optionId) == null) {
        throw StoryGenerationException(
          'la opción «$optionId» no existe en ${premise.id}.${question.id}',
        );
      }
    } else if (options.interactive && question.asksAt(age)) {
      pending = rendered;
    } else {
      optionId = engine._autoChoice(rendered, seed, index);
      auto = true;
    }
    scenes.add(
      StoryScene(
        fragmentId: variant.id,
        text: text,
        directives: variant.scene,
        choice: rendered,
        pickedOption: optionId,
      ),
    );
    if (optionId == null) break; // espera la respuesta del niño
    final option = question.optionById(optionId)!;
    state
      ..add('${question.id}:${option.id}')
      ..addAll(option.adds);
    for (final e in option.says.entries) {
      says['${question.id}.${e.key}'] = renderTemplate(e.value, cast);
    }
    chosen.add(
      ChosenOption(
        premiseId: premise.id,
        choiceId: question.id,
        optionId: option.id,
        auto: auto,
      ),
    );
  }
  return StoryRun._(
    Story(
      seed: seed,
      moral: moral,
      cast: cast,
      scenes: scenes,
      title: renderTemplate(premise.title, cast),
      moralText: moralText,
      choices: chosen,
      recipe: StoryRecipe(
        packId: pack.id,
        packVersion: pack.version,
        engineVersion: engineVersion,
        seed: seed,
        valueId: moral.id,
        cast: {for (final e in cast.entries) e.key: e.value.id},
        fragmentIds: [for (final s in scenes) s.fragmentId],
        choices: [for (final c in chosen) RecipeChoice(c.id, auto: c.auto)],
      ),
    ),
    pending,
    engine,
    options,
    picks,
  );
}

/// La pregunta con los nombres puestos.
StoryChoice _renderChoice(Choice c, Map<String, Entity> cast) => StoryChoice(
      id: c.id,
      ask: renderTemplate(c.ask, cast),
      talk: c.talk == null ? null : renderTemplate(c.talk!, cast),
      options: [
        for (final o in c.options)
          StoryOption(
            id: o.id,
            label: o.label,
            glyph: o.glyph,
            art: o.art,
          ),
      ],
    );

/// Entidades del pack que pueden ocupar una ranura.
List<Entity> castCandidates(Pack pack, CastSpec spec) {
  final List<Entity> all = switch (spec.kind) {
    'character' => pack.characters,
    'place' => pack.places,
    _ => pack.props,
  };
  return all.where((e) {
    if (spec.ids.isNotEmpty && !spec.ids.contains(e.id)) return false;
    final tags = switch (e) {
      final Character c => c.tags,
      final Place p => p.tags,
      final Prop p => p.tags,
      _ => const <String>[],
    };
    if (!spec.tags.every(tags.contains)) return false;
    if (e is Character &&
        spec.roles.isNotEmpty &&
        !spec.roles.any(e.roles.contains)) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

/// Pone el nombre del niño al héroe (si lo hay): el dibujo, el género y los atributos siguen siendo los del héroe.
Map<String, Entity> _personalize(Map<String, Entity> cast, String? heroName) {
  final hero = cast['hero'];
  if (heroName == null || hero is! Character) return cast;
  return {...cast, 'hero': hero.withGiven(heroName)};
}

/// Elige, ranura por ranura, entidades que cumplan los requisitos y no se repitan.
///
/// [heroGender] (`m`/`f`) limita el héroe a ese género. Si el niño se llama como otro personaje del pack, ese
/// personaje no se elige para el resto de ranuras (no habría dos «Mara» en el mismo cuento).
Map<String, Entity> castPremise(
  Pack pack,
  Premise premise,
  Mulberry32 rng, {
  String? heroGender,
  String? heroName,
}) {
  final chosen = <String, Entity>{};
  for (final slot in premise.cast.entries) {
    var candidates = castCandidates(pack, slot.value)
        .where((e) => !chosen.values.any((c) => c.id == e.id))
        .toList();
    if (slot.key == 'hero' && heroGender != null) {
      final byGender = candidates
          .where((e) => e.gender.name == heroGender)
          .toList(growable: false);
      if (byGender.isEmpty && heroName != null) {
        throw StoryGenerationException(
          'premisa ${premise.id}: ningún héroe de género $heroGender',
        );
      }
      if (byGender.isNotEmpty) candidates = byGender;
    }
    if (slot.key != 'hero' && heroName != null) {
      final free = candidates
          .where(
            (e) => !(e is Character &&
                e.given.toLowerCase() == heroName.toLowerCase()),
          )
          .toList(growable: false);
      if (free.isNotEmpty) candidates = free;
    }
    if (candidates.isEmpty) {
      throw StoryGenerationException(
        'premisa ${premise.id}: ninguna entidad cumple la ranura «${slot.key}»',
      );
    }
    chosen[slot.key] = rng.choice(candidates);
  }
  return chosen;
}

/// Etiquetas iniciales de un reparto: `ranura:id` y `ranura:etiqueta`.
Set<String> castState(Map<String, Entity> cast, Premise premise) {
  final state = <String>{};
  for (final e in cast.entries) {
    state.add('${e.key}:${e.value.id}');
    final tags = switch (e.value) {
      final Character c => c.tags,
      final Place p => p.tags,
      final Prop p => p.tags,
      _ => const <String>[],
    };
    for (final t in tags) {
      state.add('${e.key}:$t');
    }
  }
  return state;
}

/// Elige según el peso. Con pesos iguales equivale a `rng.choice` (misma secuencia aleatoria).
T _pickWeighted<T>(List<T> pool, double Function(T) weight, Mulberry32 rng) {
  final first = weight(pool.first);
  if (pool.every((x) => weight(x) == first)) return rng.choice(pool);
  final total = pool.fold<double>(0, (sum, x) => sum + weight(x));
  var r = rng.nextUint32() / 0x100000000 * total;
  for (final x in pool) {
    r -= weight(x);
    if (r < 0) return x;
  }
  return pool.last;
}

/// `true` si la ranura «hero» de [premise] admite un héroe de género [gender] (`m`/`f`).
bool heroCanBe(Pack pack, Premise premise, String gender) {
  final spec = premise.cast['hero'];
  return spec != null &&
      castCandidates(pack, spec).any((e) => e.gender.name == gender);
}

/// Elige héroe, ayudante, villano y dos lugares distintos.
///
/// [heroGender] limita el héroe a ese género; si no hay ninguno, con [strict] falla y sin él elige cualquiera.
Map<String, Entity> castStory(
  Pack pack,
  Mulberry32 rng, {
  String? heroGender,
  bool strict = false,
}) {
  var heroes = pack.withRole('hero');
  if (heroGender != null) {
    final byGender = heroes
        .where((c) => c.gender.name == heroGender)
        .toList(growable: false);
    if (byGender.isEmpty && strict) {
      throw StoryGenerationException(
        'el pack no tiene héroe de género $heroGender',
      );
    }
    if (byGender.isNotEmpty) heroes = byGender;
  }
  final helpers = pack.withRole('helper');
  final villains = pack.withRole('villain');
  if (heroes.isEmpty || villains.isEmpty) {
    throw StoryGenerationException(
      'el pack necesita al menos un héroe y un villano',
    );
  }
  final hero = rng.choice(heroes);
  final otherHelpers = helpers.where((c) => c.id != hero.id).toList();
  if (otherHelpers.isEmpty) {
    throw StoryGenerationException(
      'el pack necesita un ayudante distinto del héroe',
    );
  }
  final helper = rng.choice(otherHelpers);
  final villain = rng.choice(villains);
  if (pack.places.length < 2) {
    throw StoryGenerationException('el pack necesita al menos dos lugares');
  }
  final i = rng.nextInt(pack.places.length);
  var j = rng.nextInt(pack.places.length - 1);
  if (j >= i) j++;
  return {
    'hero': hero,
    'helper': helper,
    'villain': villain,
    'place': pack.places[i],
    'place2': pack.places[j],
  };
}

/// Elige un fragmento de [stage] compatible con la enseñanza y el estado.
///
/// Prefiere los fragmentos específicos de la enseñanza sobre los genéricos.
Fragment pickFragment(
  Pack pack,
  String stage,
  String valueId,
  Set<String> state,
  Set<String> used,
  Mulberry32 rng,
) {
  final candidates = pack.fragments
      .where(
        (f) =>
            f.stage == stage &&
            f.fitsValue(valueId) &&
            f.weight > 0 &&
            state.containsAll(f.requires) &&
            !used.contains(f.id),
      )
      .toList();
  final specific = candidates.where((f) => !f.isGeneric).toList();
  final pool = specific.isNotEmpty ? specific : candidates;
  if (pool.isEmpty) {
    throw StoryGenerationException(
      'sin fragmento para etapa=$stage valor=$valueId estado=${(state.toList()..sort())}',
    );
  }
  return _weightedChoice(pool, rng);
}

/// Elige un fragmento según su peso (ver [_pickWeighted]); los packs sin pesos generan
/// exactamente los mismos cuentos que antes.
Fragment _weightedChoice(List<Fragment> pool, Mulberry32 rng) =>
    _pickWeighted(pool, (f) => f.weight, rng);
