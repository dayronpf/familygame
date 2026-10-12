import 'dart:convert';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un cuento guardado en el estante: lo justo para volver a contarlo igual (la misma semilla y la misma
/// enseñanza elegida generan el mismo cuento) y para mostrarlo en una lista. Vive solo en el teléfono.
class ShelfEntry {
  const ShelfEntry({
    required this.seed,
    required this.option,
    required this.title,
    required this.moral,
    required this.moralId,
    required this.hero,
    required this.packId,
    required this.day,
    this.age,
    this.heroName,
    this.heroGender,
    this.childId,
    this.choices = const [],
  });

  factory ShelfEntry.fromStory(
    Story story, {
    required String? option,
    String? age,
    String? heroName,
    String? heroGender,
    String? childId,
  }) {
    final hero = story.cast['hero'];
    return ShelfEntry(
      seed: story.recipe.seed,
      option: option,
      title: story.title ?? story.moral.name,
      moral: story.moral.name,
      moralId: story.moral.id,
      hero: hero is Character ? hero.given : '',
      packId: story.recipe.packId,
      day: DateTime.now().toIso8601String().substring(0, 10),
      age: age,
      heroName: heroName,
      heroGender: heroGender,
      childId: childId,
      choices: [for (final c in story.choices) c.optionId],
    );
  }

  factory ShelfEntry.fromJson(Map<String, Object?> j) => ShelfEntry(
        seed: (j['seed']! as num).toInt(),
        option: j['option'] as String?,
        title: j['title']! as String,
        moral: j['moral']! as String,
        moralId: (j['moralId'] ?? '') as String,
        hero: (j['hero'] ?? '') as String,
        packId: (j['pack'] ?? 'medieval') as String,
        day: (j['day'] ?? '') as String,
        age: j['age'] as String?,
        heroName: j['heroName'] as String?,
        heroGender: j['heroGender'] as String?,
        childId: j['childId'] as String?,
        choices: [
          for (final c in (j['choices'] as List<Object?>? ?? const []))
            c as String,
        ],
      );

  /// Semilla del cuento y enseñanza que se eligió al crearlo (`null` = «Sorpréndeme»).
  final int seed;
  final String? option;
  final String title;
  final String moral;
  final String moralId;
  final String hero;
  final String packId;
  final String day;

  /// Con qué se generó, para contarlo otra vez igual: perfil de edad, nombre del protagonista y su género. Se
  /// guarda solo aquí, en el teléfono (nunca viaja con la valoración).
  final String? age;
  final String? heroName;
  final String? heroGender;

  /// De qué niño es (los estantes anteriores a los perfiles no lo tienen: se ven con todos).
  final String? childId;

  /// Ids de las opciones que se eligieron en las preguntas del cuento, en orden. Al contarlo otra vez se usan
  /// las mismas y no se pregunta (el cuento sale igual). Solo vive en el teléfono.
  final List<String> choices;

  /// Identifica el cuento (misma semilla, misma elección y mismo protagonista = mismo cuento).
  String get key =>
      '$packId:$seed:${option ?? '*'}:${age ?? ''}:${heroGender ?? ''}:${heroName ?? ''}:${childId ?? ''}';

  Map<String, Object?> toJson() => {
        'seed': seed,
        'option': option,
        'title': title,
        'moral': moral,
        'moralId': moralId,
        'hero': hero,
        'pack': packId,
        'day': day,
        if (age != null) 'age': age,
        if (heroName != null) 'heroName': heroName,
        if (heroGender != null) 'heroGender': heroGender,
        if (childId != null) 'childId': childId,
        if (choices.isNotEmpty) 'choices': choices,
      };
}

/// Dónde se guarda el estante.
abstract class ShelfStore {
  Future<String?> read();
  Future<void> write(String json);
}

class MemoryShelfStore implements ShelfStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;
}

class PrefsShelfStore implements ShelfStore {
  PrefsShelfStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'shelf.v1';

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String json) => _prefs.setString(_key, json);
}

/// «Mis cuentos»: los favoritos (el corazón) y los últimos que se contaron.
class StoryShelf extends ChangeNotifier {
  StoryShelf(this._store);

  static const int maxRecent = 12;
  static const int maxFavorites = 60;

  final ShelfStore _store;
  List<ShelfEntry> _favorites = [];
  List<ShelfEntry> _recent = [];
  bool _loaded = false;

  /// De qué niño se enseña el estante (`null` = todos). Lo que se guardó sin niño (estantes antiguos) se ve siempre.
  String? viewer;

  bool _visible(ShelfEntry e) =>
      viewer == null || e.childId == null || e.childId == viewer;

  List<ShelfEntry> get favorites =>
      List.unmodifiable(_favorites.where(_visible));
  List<ShelfEntry> get recent => List.unmodifiable(_recent.where(_visible));

  /// Borra lo que guardó un niño que ya no está.
  Future<void> removeChild(String childId) {
    _favorites.removeWhere((e) => e.childId == childId);
    _recent.removeWhere((e) => e.childId == childId);
    notifyListeners();
    return _save();
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, Object?>;
        List<ShelfEntry> list(String k) => [
              for (final e in (j[k] as List<Object?>? ?? const []))
                ShelfEntry.fromJson(e! as Map<String, Object?>),
            ];
        _favorites = list('favorites');
        _recent = list('recent');
      }
    } catch (_) {
      // Un estante ilegible se empieza de cero: no vale la pena fallar por eso.
      _favorites = [];
      _recent = [];
    }
    notifyListeners();
  }

  bool isFavorite(ShelfEntry e) => _favorites.any((x) => x.key == e.key);

  Future<void> toggleFavorite(ShelfEntry e) async {
    if (isFavorite(e)) {
      _favorites.removeWhere((x) => x.key == e.key);
    } else {
      _favorites.insert(0, e);
      if (_favorites.length > maxFavorites) _favorites.removeLast();
    }
    notifyListeners();
    await _save();
  }

  /// Anota que se contó este cuento (el más reciente primero, sin repetirlo).
  Future<void> addRecent(ShelfEntry e) async {
    _recent
      ..removeWhere((x) => x.key == e.key)
      ..insert(0, e);
    if (_recent.length > maxRecent) {
      _recent.removeRange(maxRecent, _recent.length);
    }
    notifyListeners();
    await _save();
  }

  Future<void> clearRecent() async {
    _recent = [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _store.write(jsonEncode({
        'favorites': [for (final e in _favorites) e.toJson()],
        'recent': [for (final e in _recent) e.toJson()],
      }));
}
