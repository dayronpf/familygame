import 'package:caldero_engine/caldero_engine.dart';

import '../packs/pack_catalog.dart';

/// Un cuento del catálogo: una premisa de un paquete (lo que la familia elige en «Explorar»). El texto exacto lo
/// arma el caldero con una semilla fija por cuento, así que la ficha enseña el mismo principio que luego se lee.
class CatalogStory {
  CatalogStory({required this.info, required this.pack, required this.premise})
      : moral =
            premise.value == anyValue ? null : pack.moralById(premise.value),
        minutes = estimateMinutes(premise);

  final PackInfo info;
  final Pack pack;
  final Premise premise;

  /// Enseñanza del cuento (`null` si la premisa sirve a cualquiera).
  final Moral? moral;

  /// Minutos leyendo en voz alta, aproximados.
  final int minutes;

  String get key => '${pack.id}:${premise.id}';
  String get title => premise.title;
  int get scenes => premise.beats.length;
  bool get isNew => info.isNew;

  /// Semilla fija del cuento: la ficha y la lectura salen iguales.
  int get seed => stableSeed(key);

  /// «2–3 años», «4–5 años y 6–8 años»… (vacío = todas las edades).
  String get agesLabel {
    if (premise.ages.isEmpty) return 'Todas las edades';
    final labels = [
      for (final a in premise.ages) AgeProfile.byId(a)?.label ?? a,
    ];
    return labels.join(' · ');
  }

  /// Edad mínima corta para las insignias («4+»).
  String get minAgeBadge {
    final mins = [
      for (final a in premise.ages)
        if (AgeProfile.byId(a) != null) AgeProfile.byId(a)!.minAge,
    ];
    if (mins.isEmpty) return '2+';
    mins.sort();
    return '${mins.first}+';
  }

  /// Si el cuento cabe para un niño con este nombre y género (con nombre, el héroe no puede cambiar de género).
  bool fitsChild({String? heroName, String? heroGender}) =>
      heroName == null ||
      heroGender == null ||
      heroCanBe(pack, premise, heroGender);

  /// Perfil de edad con el que se cuenta: el del niño si el cuento le sirve; si no, el primero del cuento.
  String? ageFor(String? childAge) => premise.fitsAge(childAge)
      ? childAge
      : (premise.ages.isEmpty ? childAge : premise.ages.first);

  /// Opciones para contarlo (o para la vista previa de la ficha).
  StoryOptions options({
    String? childAge,
    String? heroName,
    String? heroGender,
    bool interactive = false,
  }) {
    final gender = heroGender != null && heroCanBe(pack, premise, heroGender)
        ? heroGender
        : null;
    return StoryOptions(
      seed: seed,
      premiseId: premise.id,
      valueId: moral?.id,
      age: ageFor(childAge),
      heroName: gender == null ? null : heroName,
      heroGender: gender,
      interactive: interactive,
    );
  }

  /// Texto en minúsculas y sin tildes con lo que se puede buscar: título, enseñanza y paquete.
  late final String searchText =
      foldForSearch('$title ${moral?.name ?? ''} ${info.name} ${info.tagline}');
}

/// Minutos de un cuento leído en voz alta: la longitud media de cada escena entre ≈ 850 caracteres por minuto
/// (unas 140 palabras), redondeado hacia arriba y nunca menos de 2.
int estimateMinutes(Premise p) {
  var chars = 0.0;
  for (final b in p.beats) {
    if (b.variants.isEmpty) continue;
    chars += b.variants.map((v) => v.text.length).reduce((a, b) => a + b) /
        b.variants.length;
  }
  final m = (chars / 850).ceil();
  return m < 2 ? 2 : m;
}

/// Semilla estable a partir de un texto (FNV-1a de 32 bits).
int stableSeed(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}

const _accents = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
  'ñ': 'n',
};

/// Minúsculas y sin tildes, para buscar «valentia» y encontrar «Valentía».
String foldForSearch(String s) {
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

/// Un grupo de cuentos de «Explorar» (por edad, por enseñanza, cortos, por paquete).
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.stories,
  });

  final String id;
  final String title;
  final String emoji;
  final List<CatalogStory> stories;
}

/// Todos los cuentos de los paquetes abiertos, con búsqueda y categorías.
class StoryCatalog {
  StoryCatalog(this.stories, {this.free = const {}});

  /// Arma el catálogo con los paquetes ya cargados (en el orden de [packCatalog]).
  factory StoryCatalog.fromPacks(Map<String, Pack> packs) => StoryCatalog([
        for (final info in packCatalog)
          if (info.available && packs[info.id] != null)
            for (final p in packs[info.id]!.premises)
              CatalogStory(info: info, pack: packs[info.id]!, premise: p),
      ]);

  final List<CatalogStory> stories;

  /// Cuentos gratis («paquete:premisa»): salen en su propia categoría, la primera.
  final Set<String> free;

  /// Solo los que le caben a este niño.
  StoryCatalog forChild({String? heroName, String? heroGender}) =>
      StoryCatalog([
        for (final s in stories)
          if (s.fitsChild(heroName: heroName, heroGender: heroGender)) s,
      ], free: free);

  /// Sin los cuentos rechazados en el panel, y con la lista de gratis (vacía si ya tiene la suscripción).
  StoryCatalog withAccess(
          {required Set<String> hidden, Set<String> free = const {}}) =>
      StoryCatalog([
        for (final s in stories)
          if (!hidden.contains(s.key)) s,
      ], free: free);

  /// Cuentos cuyo título, enseñanza o paquete contienen todas las palabras buscadas (sin importar tildes).
  List<CatalogStory> search(String query) {
    final words = foldForSearch(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    return [
      for (final s in stories)
        if (words.every(s.searchText.contains)) s,
    ];
  }

  /// Los de los paquetes marcados como nuevos.
  List<CatalogStory> get newest => [
        for (final s in stories)
          if (s.isNew) s
      ];

  static const int shortMinutes = 4;

  /// Categorías con al menos un cuento: por edad, cortos, por enseñanza y por paquete.
  List<CatalogCategory> get categories {
    const ageEmoji = {'2-3': '🧸', '4-5': '🎈', '6-8': '🚲', '9-12': '🔭'};
    final out = <CatalogCategory>[
      CatalogCategory(
        id: 'free',
        title: 'Cuentos gratis',
        emoji: '🎁',
        stories: [
          for (final s in stories)
            if (free.contains(s.key)) s,
        ],
      ),
      for (final a in AgeProfile.all)
        CatalogCategory(
          id: 'age:${a.id}',
          title: a.label,
          emoji: ageEmoji[a.id] ?? '⭐',
          stories: [
            for (final s in stories)
              if (s.premise.ages.isEmpty || s.premise.ages.contains(a.id)) s,
          ],
        ),
      CatalogCategory(
        id: 'short',
        title: 'Cuentos cortos',
        emoji: '⏱️',
        stories: [
          for (final s in stories)
            if (s.minutes <= shortMinutes) s,
        ],
      ),
    ];
    final morals = <String, Moral>{};
    for (final s in stories) {
      if (s.moral != null) morals.putIfAbsent(s.moral!.id, () => s.moral!);
    }
    for (final m in morals.values) {
      out.add(CatalogCategory(
        id: 'moral:${m.id}',
        title: m.name,
        emoji: _moralEmoji[m.id] ?? '✨',
        stories: [
          for (final s in stories)
            if (s.moral?.id == m.id) s,
        ],
      ));
    }
    for (final info in packCatalog) {
      final list = [
        for (final s in stories)
          if (s.info.id == info.id) s,
      ];
      if (list.isEmpty) continue;
      out.add(CatalogCategory(
        id: 'pack:${info.id}',
        title: info.name,
        emoji: _packEmoji[info.id] ?? '📚',
        stories: list,
      ));
    }
    return [
      for (final c in out)
        if (c.stories.isNotEmpty) c,
    ];
  }
}

const _moralEmoji = {
  'honestidad': '💎',
  'generosidad': '🎁',
  'valentia': '🦁',
  'humildad': '🌱',
  'perseverancia': '🐢',
  'amistad': '🤝',
};

const _packEmoji = {
  'medieval': '🏰',
  'mar': '⛵',
  'cosmos': '🚀',
  'bosque': '🌲',
  'granja': '🐔',
};

/// Cuentos recomendados para un niño, el primero es «el cuento de esta noche». Sirven a su edad, no se contaron
/// hace poco y, si se puede, enseñan algo distinto de lo último. El orden cambia cada día pero es el mismo todo el
/// día (no salta al volver al inicio).
List<CatalogStory> recommend(
  StoryCatalog catalog, {
  String? childAge,
  String? childId,
  required String day,
  List<({String? premiseId, String packId, String moralId})> recent = const [],
  int count = 3,
}) {
  final told = {
    for (final r in recent)
      if (r.premiseId != null) '${r.packId}:${r.premiseId}',
  };
  final lastMorals = {for (final r in recent.take(3)) r.moralId};
  final byAge = [
    for (final s in catalog.stories)
      if (s.premise.fitsAge(childAge)) s,
  ];
  final pool = byAge.isEmpty ? catalog.stories : byAge;
  int score(CatalogStory s) =>
      (told.contains(s.key) ? 4 : 0) +
      (s.moral != null && lastMorals.contains(s.moral!.id) ? 2 : 0) -
      (s.isNew ? 1 : 0);
  final salt = stableSeed('$day:${childId ?? ''}');
  final ranked = [...pool]..sort((a, b) {
      final c = score(a).compareTo(score(b));
      if (c != 0) return c;
      return (stableSeed(a.key) ^ salt).compareTo(stableSeed(b.key) ^ salt);
    });
  return ranked.take(count).toList(growable: false);
}
