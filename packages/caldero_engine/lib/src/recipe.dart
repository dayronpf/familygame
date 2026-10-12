/// Versión del algoritmo del motor. Sube cuando cambie cómo se arma un cuento.
const String engineVersion = '0.3.0';

/// La «receta» de un cuento: todo lo necesario para saber QUÉ cuento fue, sin su texto
/// y sin ningún dato personal. Es lo que viaja junto a una valoración.
///
/// Es autodescriptiva (lleva los ids de fragmentos y reparto), así que sigue sirviendo
/// aunque el algoritmo del motor cambie en el futuro.
class StoryRecipe {
  const StoryRecipe({
    required this.packId,
    required this.packVersion,
    required this.engineVersion,
    required this.seed,
    required this.valueId,
    required this.cast,
    required this.fragmentIds,
    this.choices = const [],
  });

  factory StoryRecipe.fromJson(Map<String, Object?> j) => StoryRecipe(
        packId: j['packId']! as String,
        packVersion: j['packVersion']! as String,
        engineVersion: j['engine']! as String,
        seed: (j['seed']! as num).toInt(),
        valueId: j['value']! as String,
        cast: Map<String, String>.from(j['cast']! as Map<String, Object?>),
        fragmentIds: List<String>.from(j['fragments']! as List<Object?>),
        choices: [
          for (final c in (j['choices'] as List<Object?>? ?? const []))
            RecipeChoice(
              (c! as Map<String, Object?>)['id']! as String,
              auto: c['auto'] == true,
            ),
        ],
      );

  final String packId, packVersion, engineVersion, valueId;
  final int seed;

  /// Rol → id (`hero`, `helper`, `villain`, `place`, `place2`).
  final Map<String, String> cast;

  /// Ids de los fragmentos elegidos, en orden de etapa.
  final List<String> fragmentIds;

  /// Elecciones hechas (solo ids de opciones y si las hizo la app): vacío en los cuentos sin pregunta.
  final List<RecipeChoice> choices;

  Map<String, Object?> toJson() => {
        'packId': packId,
        'packVersion': packVersion,
        'engine': engineVersion,
        'seed': seed,
        'value': valueId,
        'cast': cast,
        'fragments': fragmentIds,
        if (choices.isNotEmpty)
          'choices': [
            for (final c in choices) {'id': c.id, 'auto': c.auto},
          ],
      };
}

/// Una elección dentro de la receta: id `premisa.elección.opción` y si la hizo la app.
class RecipeChoice {
  const RecipeChoice(this.id, {required this.auto});

  final String id;
  final bool auto;
}
