import 'recipe.dart';

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

/// Atributos que no pueden usarse como nombre propio porque ya tienen una forma gramatical.
const Set<String> reservedForms = {
  'noun', 'el', 'un', 'del', 'al', 'en', 'o', 'trait', //
  'El', 'Un', 'En',
};

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
    this.tags = const [],
    this.attrs = const {},
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
      tags: _strList(j, 'tags', where),
      attrs: _attrs(j, where),
    );
  }

  /// Nombre propio («Nilo»).
  final String given;

  /// El mismo personaje con otro nombre (el del niño que escucha el cuento): conserva id, dibujo, género y atributos.
  Character withGiven(String name) => Character(
        id: id,
        noun: noun,
        gender: gender,
        given: name,
        roles: roles,
        alignment: alignment,
        trait: trait,
        tags: tags,
        attrs: attrs,
      );

  /// `hero`, `helper`, `villain`…
  final List<String> roles;

  /// `positive`, `negative` o `ambiguous`.
  final String alignment;

  /// Adjetivo según género: `{'m': 'curioso', 'f': 'curiosa'}`.
  final Map<String, String> trait;

  /// Etiquetas para que las premisas elijan al personaje adecuado (`greedy`, `wise`…).
  final List<String> tags;

  /// Frases propias del personaje que los textos usan como `{rol.atributo}`: su gesto al
  /// pensar, cómo se le nota el miedo, dónde vive… Dan a cada personaje una voz distinta.
  /// Cada atributo puede tener VARIAS formas (se alternan para que no se repitan en un cuento).
  final Map<String, List<String>> attrs;
}

Map<String, List<String>> _attrs(Map<String, Object?> j, String where) {
  final raw = j['attrs'];
  if (raw == null) {
    return const {};
  }
  if (raw is! Map) {
    throw PackFormatException('$where: "attrs" debe ser un objeto');
  }
  final attrs = <String, List<String>>{};
  for (final e in raw.entries) {
    final k = e.key as String;
    if (reservedForms.contains(k) || !RegExp(r'^[a-z]\w*$').hasMatch(k)) {
      throw PackFormatException('$where: atributo no permitido "$k"');
    }
    final v = e.value;
    final options = v is String
        ? [v]
        : v is List &&
                v.isNotEmpty &&
                v.every((x) => x is String && x.isNotEmpty)
            ? List<String>.from(v)
            : throw PackFormatException(
                '$where: el atributo "$k" debe ser un texto o una lista de textos',
              );
    attrs[k] = options;
  }
  return attrs;
}

class Place extends Entity {
  const Place({
    required super.id,
    required super.noun,
    required super.gender,
    required this.mood,
    this.tags = const [],
    this.times,
    this.seasons = const [],
    this.features,
  });

  factory Place.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'lugar');
    final where = 'lugar "$id"';
    return Place(
      id: id,
      noun: _str(j, 'noun', where),
      gender: Gender.parse(j['gender'], where),
      mood: _str(j, 'mood', where),
      tags: _strList(j, 'tags', where),
      times: j.containsKey('times') ? _strList(j, 'times', where) : null,
      seasons: _strList(j, 'seasons', where),
      features:
          j.containsKey('features') ? _strList(j, 'features', where) : null,
    );
  }

  final String mood;

  /// Horas del día que el arte sabe dibujar en este lugar (`dia`, `amanecer`, `atardecer`, `noche`).
  /// `null` = el lugar no distingue horas (no se comprueba).
  final List<String>? times;

  /// Estaciones que el arte sabe dibujar (`invierno`, `primavera`, `otono`); vacío = solo la normal.
  final List<String> seasons;

  /// Rasgos que el arte dibuja en el lugar (`pozo`, `ventana`, `cama`…). `null` = no se comprueba.
  final List<String>? features;

  /// Para qué sirve el lugar en una trama (`village`, `castle`, `forest`, `cave`, `water`…).
  final List<String> tags;
}

/// Un objeto de la trama (una campana, un farol…). Se elige para cada cuento y sus textos
/// lo nombran con `{item}`, `{item.el}`, etc.
class Prop extends Entity {
  const Prop({
    required super.id,
    required super.noun,
    required super.gender,
    this.tags = const [],
  });

  factory Prop.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'objeto');
    final where = 'objeto "$id"';
    return Prop(
      id: id,
      noun: _str(j, 'noun', where),
      gender: Gender.parse(j['gender'], where),
      tags: _strList(j, 'tags', where),
    );
  }

  final List<String> tags;
}

class Moral {
  const Moral({
    required this.id,
    required this.name,
    required this.text,
    this.simple = const {},
  });

  factory Moral.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'enseñanza');
    final where = 'enseñanza "$id"';
    final simple = <String, String>{};
    final raw = j['simple'];
    if (raw != null) {
      if (raw is! Map<String, Object?>) {
        throw PackFormatException('$where: "simple" debe ser un objeto');
      }
      for (final e in raw.entries) {
        final v = e.value;
        if (v is! String || v.trim().isEmpty) {
          throw PackFormatException(
            '$where: "simple.${e.key}" debe ser un texto',
          );
        }
        if (!const ['2-3', '4-5', '6-8', '9-12'].contains(e.key)) {
          throw PackFormatException(
            '$where: edad "${e.key}" desconocida en "simple"',
          );
        }
        simple[e.key] = v;
      }
    }
    return Moral(
      id: id,
      name: _str(j, 'name', where),
      text: _str(j, 'text', where),
      simple: simple,
    );
  }

  final String id;

  /// Nombre para mostrar: «Valentía».
  final String name;

  /// Frase de cierre del cuento.
  final String text;

  /// Formas más sencillas de la frase para los más pequeños (`2-3`, `4-5`), por perfil de edad.
  final Map<String, String> simple;

  /// La frase para [age]: la sencilla si la hay y, si no, la de siempre.
  String textFor(String? age) => simple[age] ?? text;
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
    this.weight = 1,
  });

  factory Fragment.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'fragmento');
    final where = 'fragmento "$id"';
    final stage = _str(j, 'stage', where);
    if (!storyStages.contains(stage)) {
      throw PackFormatException('$where: etapa desconocida "$stage"');
    }
    final scene = j['scene'];
    final weight = j['weight'];
    if (weight != null && (weight is! num || weight < 0 || !weight.isFinite)) {
      throw PackFormatException('$where: "weight" debe ser un número ≥ 0');
    }
    return Fragment(
      id: id,
      stage: stage,
      values: _strList(j, 'values', where, required: true),
      requires: _strList(j, 'requires', where),
      adds: _strList(j, 'adds', where),
      text: _str(j, 'text', where),
      scene: scene is Map<String, Object?> ? scene : const {},
      weight: weight == null ? 1 : (weight as num).toDouble(),
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

  /// Probabilidad relativa de salir elegido (1 = normal, 0 = desactivado).
  ///
  /// Es contenido del pack: la mejora continua ajusta estos pesos con las valoraciones y se
  /// publican como una versión nueva del pack, así que cada cuento sigue siendo reproducible.
  final double weight;

  bool fitsValue(String valueId) =>
      values.contains(anyValue) || values.contains(valueId);

  bool get isGeneric => values.contains(anyValue);
}

/// Qué entidad puede ocupar una ranura del reparto de una premisa.
class CastSpec {
  const CastSpec({
    required this.kind,
    this.roles = const [],
    this.tags = const [],
    this.ids = const [],
  });

  factory CastSpec.fromJson(Map<String, Object?> j, String where) {
    final kind = j['kind'];
    if (kind != 'character' && kind != 'place' && kind != 'prop') {
      throw PackFormatException(
        '$where: "kind" debe ser "character", "place" o "prop"',
      );
    }
    return CastSpec(
      kind: kind! as String,
      roles: _strList(j, 'roles', where),
      tags: _strList(j, 'tags', where),
      ids: _strList(j, 'ids', where),
    );
  }

  /// `character`, `place` o `prop`.
  final String kind;

  /// Solo personajes: debe tener alguno de estos roles.
  final List<String> roles;

  /// Debe tener TODAS estas etiquetas.
  final List<String> tags;

  /// Si no está vacío, solo estos ids.
  final List<String> ids;
}

/// Una forma de contar una escena. Todas las variantes de una escena cuentan los MISMOS hechos
/// (cambian las palabras, no lo que ocurre), así que son intercambiables.
class Variant {
  const Variant({
    required this.id,
    required this.text,
    required this.requires,
    required this.adds,
    required this.scene,
    this.weight = 1,
  });

  /// Id completo `premisa.escena.variante`; es lo que viaja en la receta.
  final String id;
  final String text;

  /// Etiquetas que deben existir: las del reparto (`villain:greedy`, `hero:aldo`) o las que
  /// añadió una escena anterior.
  final List<String> requires;
  final List<String> adds;

  /// Directivas de animación (`bg` = ranura de lugar, `actors` = ranuras de personaje, `mood`).
  final Map<String, Object?> scene;
  final double weight;
}

/// Iconos que puede llevar una opción: nombres de Material Icons (lista cerrada; la app los dibuja). Nunca
/// emojis: cambian de aspecto por teléfono y la voz los borra, así que no pueden ser la única pista.
const Set<String> choiceGlyphs = {
  'hearing',
  'touch_app',
  'hourglass_bottom',
  'visibility',
  'pets',
  'air',
  'spa',
  'search',
  'forest',
  'self_improvement',
  'explore',
  'volume_up',
  'lightbulb',
  'waving_hand',
  'directions_walk',
  'music_note',
  'nightlight_round',
  'favorite',
};

/// Capacidades opcionales de un pack que este motor entiende (`pack.features`).
const Set<String> supportedFeatures = {'choice@1'};

final RegExp _artId = RegExp(r'^[a-z][a-z0-9_]*$');

/// Una de las 2–3 opciones de una pregunta al niño.
class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.label,
    required this.glyph,
    this.art,
    this.adds = const [],
    this.says = const {},
  });

  /// Elegir esta opción añade la etiqueta `idElección:id` (más [adds]) al estado.
  final String id;

  /// Lo que se ve y se dice en la tarjeta (corto, sin puntuación).
  final String label;
  final String glyph;

  /// Dibujo propio de la tarjeta (id de un rig del arte del pack). [glyph] es el icono de repuesto si ese dibujo
  /// no está.
  final String? art;
  final List<String> adds;

  /// Frases que las escenas siguientes usan como `{idElección.clave}`.
  final Map<String, String> says;
}

/// Una pregunta al niño al final de una escena: «¿cómo sigue {hero} en la oscuridad?».
class Choice {
  const Choice({
    required this.id,
    required this.ask,
    required this.options,
    this.talk,
    this.ages = const [],
  });

  final String id;

  /// La pregunta, con tokens; se lee en voz alta.
  final String ask;

  /// Para el adulto: qué preguntarle al niño. Solo se ve en la pantalla de texto.
  final String? talk;

  /// Perfiles de edad en los que se pregunta (vacío = 6-8 y 9-12). En el resto la app elige sola.
  final List<String> ages;
  final List<ChoiceOption> options;

  static const List<String> defaultAges = ['6-8', '9-12'];

  bool asksAt(String? age) =>
      age != null && (ages.isEmpty ? defaultAges : ages).contains(age);

  ChoiceOption? optionById(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  static Choice fromJson(Map<String, Object?> j, String where) {
    final id = _str(j, 'id', where);
    final w = '$where, elección "$id"';
    final options = <ChoiceOption>[];
    for (final o in _objList(j, 'options')) {
      final oid = _str(o, 'id', w);
      final ow = '$w, opción "$oid"';
      final icon = o['icon'];
      if (icon is! Map<String, Object?> || icon['glyph'] is! String) {
        throw PackFormatException(
          '$ow: "icon" debe ser {"glyph": "nombre de Material Icons"} (y, si se quiere, "art": id de un dibujo)',
        );
      }
      final art = icon['art'];
      if (art != null && (art is! String || !_artId.hasMatch(art))) {
        throw PackFormatException(
          '$ow: icon.art debe ser el id de un dibujo (minúsculas, cifras y «_»)',
        );
      }
      final says = o['says'];
      if (says != null &&
          (says is! Map || !says.values.every((v) => v is String))) {
        throw PackFormatException('$ow: "says" debe ser un objeto de textos');
      }
      options.add(
        ChoiceOption(
          id: oid,
          label: _str(o, 'label', ow),
          glyph: icon['glyph']! as String,
          art: art as String?,
          adds: _strList(o, 'adds', ow),
          says: says == null
              ? const {}
              : {
                  for (final e in (says as Map).entries)
                    e.key as String: e.value as String,
                },
        ),
      );
    }
    return Choice(
      id: id,
      ask: _str(j, 'ask', w),
      talk: j['talk'] is String ? j['talk']! as String : null,
      ages: _strList(j, 'ages', w),
      options: options,
    );
  }
}

/// Una escena de la premisa, con sus variantes.
class Beat {
  const Beat({
    required this.id,
    required this.variants,
    required this.introduces,
    required this.moves,
    this.choice,
  });

  /// Si lleva pregunta, se cuenta primero la escena y después se pregunta.
  final Choice? choice;

  final String id;
  final List<Variant> variants;

  /// Ranuras (personajes u objetos) que se presentan aquí: el texto debe nombrarlas y ninguna
  /// escena anterior puede haberlo hecho.
  final List<String> introduces;

  /// El texto cuenta un desplazamiento a otro lugar (obligatorio si cambia el fondo).
  final bool moves;
}

/// Una historia completa escrita por un autor: reparto con requisitos, hechos compartidos
/// (objetos) y escenas con variantes. Es la unidad con la que el motor garantiza el hilo.
class Premise {
  const Premise({
    required this.id,
    required this.value,
    required this.title,
    required this.cast,
    required this.beats,
    this.npcs = const {},
    this.weight = 1,
    this.ages = const [],
  });

  factory Premise.fromJson(Map<String, Object?> j) {
    final id = _str(j, 'id', 'premisa');
    final where = 'premisa "$id"';
    final castJson = j['cast'];
    if (castJson is! Map<String, Object?> || castJson.isEmpty) {
      throw PackFormatException('$where: falta el reparto "cast"');
    }
    final cast = {
      for (final e in castJson.entries)
        e.key: CastSpec.fromJson(
          e.value is Map<String, Object?>
              ? e.value! as Map<String, Object?>
              : throw PackFormatException('$where: ranura "${e.key}" inválida'),
          '$where, ranura "${e.key}"',
        ),
    };
    final beats = <Beat>[];
    for (final b in _objList(j, 'beats')) {
      final beatId = _str(b, 'id', where);
      final bw = '$where, escena "$beatId"';
      final variants = [
        for (final v in _objList(b, 'variants'))
          () {
            final vid = _str(v, 'id', bw);
            final vw = '$bw, variante "$vid"';
            final weight = v['weight'];
            if (weight != null &&
                (weight is! num || weight < 0 || !weight.isFinite)) {
              throw PackFormatException('$vw: "weight" debe ser un número ≥ 0');
            }
            final scene = v['scene'];
            return Variant(
              id: '$id.$beatId.$vid',
              text: _str(v, 'text', vw),
              requires: _strList(v, 'requires', vw),
              adds: _strList(v, 'adds', vw),
              scene: scene is Map<String, Object?> ? scene : const {},
              weight: weight == null ? 1 : (weight as num).toDouble(),
            );
          }(),
      ];
      if (variants.isEmpty) {
        throw PackFormatException('$bw: necesita al menos una variante');
      }
      beats.add(
        Beat(
          id: beatId,
          variants: variants,
          introduces: _strList(b, 'introduces', bw),
          moves: b['moves'] == true,
          choice: b['choice'] == null
              ? null
              : b['choice'] is Map<String, Object?>
                  ? Choice.fromJson(b['choice']! as Map<String, Object?>, bw)
                  : throw PackFormatException(
                      '$bw: "choice" debe ser un objeto',
                    ),
        ),
      );
    }
    if (beats.isEmpty) {
      throw PackFormatException('$where: no tiene escenas');
    }
    final weight = j['weight'];
    final npcsJson = j['npcs'];
    final npcs = <String, List<String>>{};
    if (npcsJson != null) {
      if (npcsJson is! Map) {
        throw PackFormatException('$where: "npcs" debe ser un objeto');
      }
      for (final e in npcsJson.entries) {
        final v = e.value;
        if (v is! List ||
            v.isEmpty ||
            !v.every((x) => x is String && x.isNotEmpty)) {
          throw PackFormatException(
            '$where: "npcs.${e.key}" debe ser una lista de palabras con las que el texto nombra al personaje',
          );
        }
        npcs[e.key as String] = List<String>.from(v);
      }
    }
    final ages = _strList(j, 'ages', where);
    for (final a in ages) {
      if (!const ['2-3', '4-5', '6-8', '9-12'].contains(a)) {
        throw PackFormatException(
          '$where: edad "$a" desconocida (usa 2-3, 4-5, 6-8 o 9-12)',
        );
      }
    }
    return Premise(
      id: id,
      value: _str(j, 'value', where),
      title: _str(j, 'title', where),
      cast: cast,
      beats: beats,
      npcs: npcs,
      weight: weight is num ? weight.toDouble() : 1,
      ages: ages,
    );
  }

  final String id;

  /// Perfiles de edad (`2-3`, `4-5`, `6-8`, `9-12`) a los que sirve el cuento; vacío = todos.
  final List<String> ages;

  bool fitsAge(String? age) =>
      age == null || ages.isEmpty || ages.contains(age);

  /// Enseñanza que ilustra (id de `morals`), o `*`.
  final String value;

  /// Título del cuento; puede llevar tokens (`La {item.noun}…`).
  final String title;

  /// Ranura → requisitos. El orden de declaración es el orden en que se eligen.
  final Map<String, CastSpec> cast;
  final List<Beat> beats;

  /// Personajes secundarios que salen en las ilustraciones (id del dibujo → palabras con que el texto los
  /// nombra: «Tomás», «herrero»…). El validador exige que quien se nombra se dibuje y viceversa.
  final Map<String, List<String>> npcs;
  final double weight;

  bool fitsValue(String valueId) => value == anyValue || value == valueId;
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
    this.props = const [],
    this.premises = const [],
    this.features = const [],
  });

  /// Capacidades que el pack declara necesitar (`choice@1`: preguntas al niño).
  final List<String> features;

  /// Esquemas de pack que entiende este motor: 1 (fragmentos por etapa) y 2 (premisas).
  static const Set<int> supportedSchemas = {1, 2};

  factory Pack.fromJson(Map<String, Object?> json) {
    final meta = json['pack'];
    if (meta is! Map<String, Object?>) {
      throw PackFormatException('falta el bloque "pack"');
    }
    final schema = meta['schema'];
    if (!supportedSchemas.contains(schema)) {
      throw PackFormatException(
        'esquema de pack no soportado: $schema (este motor entiende $supportedSchemas)',
      );
    }
    final features = _strList(meta, 'features', 'pack');
    for (final f in features) {
      if (!supportedFeatures.contains(f)) {
        throw PackFormatException(
          'el pack necesita «$f», que este motor no entiende (entiende $supportedFeatures)',
        );
      }
    }
    return Pack(
      features: features,
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
      fragments: schema == 1 || json['fragments'] != null
          ? _objList(json, 'fragments')
              .map(Fragment.fromJson)
              .toList(growable: false)
          : const [],
      props: json['props'] == null
          ? const []
          : _objList(json, 'props').map(Prop.fromJson).toList(growable: false),
      premises: json['premises'] == null
          ? const []
          : _objList(json, 'premises')
              .map(Premise.fromJson)
              .toList(growable: false),
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

  /// Objetos de la trama (esquema 2).
  final List<Prop> props;

  /// Historias completas (esquema 2).
  final List<Premise> premises;

  Moral? moralById(String id) {
    for (final m in morals) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Enseñanzas que tienen algún cuento en este pack (un pack en construcción puede no tenerlas todas). Un pack
  /// solo de fragmentos (esquema 1) las cuenta todas.
  List<Moral> get moralsWithStories => premises.isEmpty
      ? morals
      : morals
          .where((m) => premises.any((p) => p.fitsValue(m.id)))
          .toList(growable: false);

  List<Character> withRole(String role) =>
      characters.where((c) => c.roles.contains(role)).toList(growable: false);
}

/// Una escena ya renderizada: texto + directivas de animación.
class StoryScene {
  const StoryScene({
    required this.fragmentId,
    required this.text,
    required this.directives,
    this.choice,
    this.pickedOption,
  });

  final String fragmentId;
  final String text;
  final Map<String, Object?> directives;

  /// La pregunta que sigue a esta escena (ya con los nombres puestos), si la tiene.
  final StoryChoice? choice;

  /// Opción elegida en [choice] (`null` mientras la pregunta está sin responder).
  final String? pickedOption;
}

/// Una opción lista para enseñar.
class StoryOption {
  const StoryOption({
    required this.id,
    required this.label,
    required this.glyph,
    this.art,
  });

  final String id, label, glyph;

  /// Dibujo propio de la tarjeta, si lo tiene (si no, se usa [glyph]).
  final String? art;
}

/// Una pregunta al niño con los tokens ya resueltos.
class StoryChoice {
  const StoryChoice({
    required this.id,
    required this.ask,
    required this.options,
    this.talk,
  });

  final String id, ask;
  final String? talk;
  final List<StoryOption> options;

  StoryOption? optionById(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Lo que la voz dice: la pregunta y cada opción, una frase corta por opción.
  String get spoken => '$ask ${options.map((o) => '${o.label}.').join(' ')}';
}

/// Una elección ya hecha. En la receta viaja solo [id] (`premisa.elección.opción`) y [auto].
class ChosenOption {
  const ChosenOption({
    required this.premiseId,
    required this.choiceId,
    required this.optionId,
    required this.auto,
  });

  final String premiseId, choiceId, optionId;

  /// `true` si la eligió la app (por espera, ajuste de la familia o temporizador); `false` si tocó el niño.
  final bool auto;

  String get id => '$premiseId.$choiceId.$optionId';
}

class Story {
  const Story({
    required this.seed,
    required this.moral,
    required this.cast,
    required this.scenes,
    required this.recipe,
    this.title,
    String? moralText,
    this.choices = const [],
  }) : moralText = moralText ?? '';

  /// Elecciones hechas en este cuento, en orden.
  final List<ChosenOption> choices;

  final int seed;

  /// La enseñanza dicha para la edad del niño (puede ser la forma sencilla). Vacío = la de [moral].
  final String moralText;

  /// La frase de enseñanza que se lee y se narra.
  String get moralLine => moralText.isEmpty ? moral.text : moralText;

  /// Título del cuento (solo las premisas lo tienen).
  final String? title;
  final Moral moral;

  /// Roles `hero`, `helper`, `villain`, `place`, `place2`.
  final Map<String, Entity> cast;
  final List<StoryScene> scenes;

  /// Identifica este cuento (sin texto ni datos personales); viaja con la valoración.
  final StoryRecipe recipe;

  /// Texto completo del cuento, con la enseñanza al final.
  String get fullText =>
      '${scenes.map((s) => s.text).join('\n\n')}\n\nEnseñanza: $moralLine';
}
