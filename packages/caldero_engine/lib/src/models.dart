/// Error de formato en un pack de contenido.
class PackFormatException implements Exception {
  PackFormatException(this.message);

  final String message;

  @override
  String toString() => 'PackFormatException: $message';
}

/// Etapas del esqueleto narrativo, en orden.
const List<String> storyStages = [
  'opening',
  'trouble',
  'helper',
  'test',
  'climax',
  'resolution',
  'closing',
];

/// Comodín de `values` para fragmentos válidos con cualquier enseñanza.
const String anyValue = '*';

enum Gender {
  m,
  f;

  static Gender parse(Object? raw, String where) => switch (raw) {
        'm' => Gender.m,
        'f' => Gender.f,
        _ => throw PackFormatException('$where: "gender" debe ser "m" o "f"'),
      };
}

// --- Lectura defensiva del JSON ---------------------------------------

String _str(Map<String, Object?> j, String key, String where) {
  final v = j[key];
  if (v is String && v.isNotEmpty) return v;
  throw PackFormatException('$where: falta el texto "$key"');
}

List<String> _strList(
  Map<String, Object?> j,
  String key,
  String where, {
  bool required = false,
}) {
  final v = j[key];
  if (v == null) {
    if (required) throw PackFormatException('$where: falta la lista "$key"');
    return const [];
  }
  if (v is List && v.every((e) => e is String)) return List<String>.from(v);
  throw PackFormatException('$where: "$key" debe ser una lista de textos');
}

List<Map<String, Object?>> _objList(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is List && v.every((e) => e is Map<String, Object?>)) {
    return List<Map<String, Object?>>.from(v);
  }
  throw PackFormatException('el pack debe tener una lista de objetos "$key"');
}

/// Algo con nombre y género gramatical que puede aparecer en un cuento.
abstract class Entity {
  const Entity({required this.id, required this.noun, required this.gender});

  final String id;

  /// Sustantivo sin artículo: «erizo», «bosque de las luciérnagas».
  final String noun;
  final Gender gender;
}

class Character extends Entity {
  const Character({
    required super.id,
    required super.noun,
    required super.gender,
    required this.given,
    required this.roles,
    required this.alignment,
    required this.trait,
  });

  factory Character.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'personaje');
    final where = 'personaje "$id"';
    final trait = j['trait'];
    if (trait is! Map<String, Object?> ||
        trait['m'] is! String ||
        trait['f'] is! String) {
      throw PackFormatException(
        '$where: "trait" debe tener las formas "m" y "f"',
      );
    }
    return Character(
      id: id,
      noun: _str(j, 'noun', where),
      gender: Gender.parse(j['gender'], where),
      given: _str(j, 'given', where),
      roles: _strList(j, 'roles', where, required: true),
      alignment: _str(j, 'alignment', where),
      trait: {'m': trait['m']! as String, 'f': trait['f']! as String},
    );
  }

  /// Nombre propio («Nilo»).
  final String given;

  /// `hero`, `helper`, `villain`…
  final List<String> roles;

  /// `positive`, `negative` o `ambiguous`.
  final String alignment;

  /// Adjetivo según género: `{'m': 'curioso', 'f': 'curiosa'}`.
  final Map<String, String> trait;
}

class Place extends Entity {
  const Place({
    required super.id,
    required super.noun,
    required super.gender,
    required this.mood,
  });

  factory Place.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'lugar');
    final where = 'lugar "$id"';
    return Place(
      id: id,
      noun: _str(j, 'noun', where),
      gender: Gender.parse(j['gender'], where),
      mood: _str(j, 'mood', where),
    );
  }

  final String mood;
}

class Moral {
  const Moral({required this.id, required this.name, required this.text});

  factory Moral.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'enseñanza');
    final where = 'enseñanza "$id"';
    return Moral(
      id: id,
      name: _str(j, 'name', where),
      text: _str(j, 'text', where),
    );
  }

  final String id;

  /// Nombre para mostrar: «Valentía».
  final String name;

  /// Frase de cierre del cuento.
  final String text;
}

class Fragment {
  const Fragment({
    required this.id,
    required this.stage,
    required this.values,
    required this.requires,
    required this.adds,
    required this.text,
    required this.scene,
  });

  factory Fragment.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'fragmento');
    final where = 'fragmento "$id"';
    final stage = _str(j, 'stage', where);
    if (!storyStages.contains(stage)) {
      throw PackFormatException('$where: etapa desconocida "$stage"');
    }
    final scene = j['scene'];
    return Fragment(
      id: id,
      stage: stage,
      values: _strList(j, 'values', where, required: true),
      requires: _strList(j, 'requires', where),
      adds: _strList(j, 'adds', where),
      text: _str(j, 'text', where),
      scene: scene is Map<String, Object?> ? scene : const {},
    );
  }

  final String id;
  final String stage;

  /// Enseñanzas con las que encaja, o `["*"]`.
  final List<String> values;

  /// Etiquetas de estado que deben existir antes.
  final List<String> requires;

  /// Etiquetas de estado que este fragmento añade.
  final List<String> adds;

  /// Plantilla con tokens como `{hero.el}`.
  final String text;

  /// Directivas de animación (fondo, actores, ánimo…).
  final Map<String, Object?> scene;

  bool fitsValue(String valueId) =>
      values.contains(anyValue) || values.contains(valueId);

  bool get isGeneric => values.contains(anyValue);
}

class Pack {
  const Pack({
    required this.id,
    required this.name,
    required this.version,
    required this.language,
    required this.characters,
    required this.places,
    required this.morals,
    required this.fragments,
  });

  /// Versión del esquema de pack que entiende este motor.
  static const int supportedSchema = 1;

  factory Pack.fromJson(Map<String, Object?> json) {
    final meta = json['pack'];
    if (meta is! Map<String, Object?>) {
      throw PackFormatException('falta el bloque "pack"');
    }
    final schema = meta['schema'];
    if (schema != supportedSchema) {
      throw PackFormatException(
        'esquema de pack no soportado: $schema (este motor entiende $supportedSchema)',
      );
    }
    return Pack(
      id: _str(meta, 'id', 'pack'),
      name: _str(meta, 'name', 'pack'),
      version: _str(meta, 'version', 'pack'),
      language: _str(meta, 'language', 'pack'),
      characters: _objList(
        json,
        'characters',
      ).map(Character.fromJson).toList(growable: false),
      places: _objList(
        json,
        'places',
      ).map(Place.fromJson).toList(growable: false),
      morals: _objList(
        json,
        'morals',
      ).map(Moral.fromJson).toList(growable: false),
      fragments: _objList(
        json,
        'fragments',
      ).map(Fragment.fromJson).toList(growable: false),
    );
  }

  final String id;
  final String name;
  final String version;
  final String language;
  final List<Character> characters;
  final List<Place> places;
  final List<Moral> morals;
  final List<Fragment> fragments;

  Moral? moralById(String id) {
    for (final m in morals) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<Character> withRole(String role) =>
      characters.where((c) => c.roles.contains(role)).toList(growable: false);
}

/// Una escena ya renderizada: texto + directivas de animación.
class StoryScene {
  const StoryScene({
    required this.fragmentId,
    required this.text,
    required this.directives,
  });

  final String fragmentId;
  final String text;
  final Map<String, Object?> directives;
}

class Story {
  const Story({
    required this.seed,
    required this.moral,
    required this.cast,
    required this.scenes,
  });

  final int seed;
  final Moral moral;

  /// Roles `hero`, `helper`, `villain`, `place`, `place2`.
  final Map<String, Entity> cast;
  final List<StoryScene> scenes;

  /// Texto completo del cuento, con la enseñanza al final.
  String get fullText =>
      '${scenes.map((s) => s.text).join('\n\n')}\n\nEnseñanza: ${moral.text}';
}
