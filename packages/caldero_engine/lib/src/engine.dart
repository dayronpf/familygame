import 'grammar.dart';
import 'models.dart';
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
    return Story(seed: options.seed, moral: moral, cast: cast, scenes: scenes);
  }
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
  return rng.choice(pool);
}
