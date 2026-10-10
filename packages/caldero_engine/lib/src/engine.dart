import 'grammar.dart';
import 'models.dart';
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
  const StoryOptions({required this.seed, this.valueId});

  /// Misma semilla + mismo pack + mismas opciones ⇒ mismo cuento.
  final int seed;

  /// Enseñanza deseada; si es `null` se elige una al azar.
  final String? valueId;
}

/// El «caldero»: elige enseñanza, reparto y fragmentos coherentes.
class StoryEngine {
  const StoryEngine(this.pack);

  final Pack pack;

  Story generate(StoryOptions options) {
    final rng = Mulberry32(options.seed);

    final Moral moral;
    if (options.valueId == null) {
      moral = rng.choice(pack.morals);
    } else {
      moral = pack.moralById(options.valueId!) ??
          (throw StoryGenerationException(
            'enseñanza desconocida: ${options.valueId}',
          ));
    }

    final premises = pack.premises
        .where((p) => p.fitsValue(moral.id))
        .toList(growable: false);
    if (premises.isNotEmpty) {
      return _generateFromPremise(
        pack,
        options.seed,
        moral,
        _pickWeighted(premises, (p) => p.weight, rng),
        rng,
      );
    }

    final cast = castStory(pack, rng);
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
    return Story(
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
    );
  }
}

/// Cuenta una [premise]: elige el reparto que cumple sus requisitos y, escena a escena, una
/// variante compatible con él y con lo ya contado.
Story _generateFromPremise(
  Pack pack,
  int seed,
  Moral moral,
  Premise premise,
  Mulberry32 rng,
) {
  final cast = castPremise(pack, premise, rng);
  final state = castState(cast, premise);
  final scenes = <StoryScene>[];
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
    scenes.add(
      StoryScene(
        fragmentId: variant.id,
        text: renderTemplate(variant.text, cast),
        directives: variant.scene,
      ),
    );
  }
  return Story(
    seed: seed,
    moral: moral,
    cast: cast,
    scenes: scenes,
    title: renderTemplate(premise.title, cast),
    recipe: StoryRecipe(
      packId: pack.id,
      packVersion: pack.version,
      engineVersion: engineVersion,
      seed: seed,
      valueId: moral.id,
      cast: {for (final e in cast.entries) e.key: e.value.id},
      fragmentIds: [for (final s in scenes) s.fragmentId],
    ),
  );
}

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

/// Elige, ranura por ranura, entidades que cumplan los requisitos y no se repitan.
Map<String, Entity> castPremise(Pack pack, Premise premise, Mulberry32 rng) {
  final chosen = <String, Entity>{};
  for (final slot in premise.cast.entries) {
    final candidates = castCandidates(pack, slot.value)
        .where((e) => !chosen.values.any((c) => c.id == e.id))
        .toList();
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

/// Elige héroe, ayudante, villano y dos lugares distintos.
Map<String, Entity> castStory(Pack pack, Mulberry32 rng) {
  final heroes = pack.withRole('hero');
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
