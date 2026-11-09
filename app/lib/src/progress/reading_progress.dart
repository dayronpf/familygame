import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shelf/story_shelf.dart';

/// Un premio: se gana una vez y **nunca se pierde** (no hay rachas que castiguen; ver docs/05).
class Award {
  const Award({
    required this.id,
    required this.name,
    required this.hint,
    required this.icon,
    required this.colors,
    required this.earned,
  });

  final String id;
  final String name;

  /// Cómo se gana, dicho para el adulto.
  final String hint;
  final IconData icon;
  final List<Color> colors;
  final bool Function(ChildProgress p) earned;
}

/// Los premios, de la semilla al roble y de la primera noche a la luna llena.
final List<Award> awards = [
  Award(
    id: 'semilla',
    name: 'Primera semilla',
    hint: 'Terminar el primer cuento',
    icon: Icons.grass,
    colors: const [Color(0xFF7BD389), Color(0xFF2E7D4F)],
    earned: (p) => p.stories >= 1,
  ),
  Award(
    id: 'brote',
    name: 'Brote',
    hint: 'Terminar 5 cuentos',
    icon: Icons.spa,
    colors: const [Color(0xFF9BE08E), Color(0xFF3F8F3A)],
    earned: (p) => p.stories >= 5,
  ),
  Award(
    id: 'arbolito',
    name: 'Arbolito',
    hint: 'Terminar 25 cuentos',
    icon: Icons.park,
    colors: const [Color(0xFF6CC27A), Color(0xFF1F6B4F)],
    earned: (p) => p.stories >= 25,
  ),
  Award(
    id: 'roble',
    name: 'Roble de cuentos',
    hint: 'Terminar 100 cuentos',
    icon: Icons.forest,
    colors: const [Color(0xFF4FA36A), Color(0xFF184D33)],
    earned: (p) => p.stories >= 100,
  ),
  Award(
    id: 'semana_luna',
    name: 'Semana de luna',
    hint: 'Una semana con cuento al menos 3 noches',
    icon: Icons.nightlight_round,
    colors: const [Color(0xFFFFD36E), Color(0xFFC98A1E)],
    earned: (p) => p.storyWeeks >= 1,
  ),
  Award(
    id: 'luna_llena',
    name: 'Luna llena',
    hint: '4 semanas con cuento al menos 3 noches',
    icon: Icons.brightness_1,
    colors: const [Color(0xFFFFE7A3), Color(0xFFD4A23A)],
    earned: (p) => p.storyWeeks >= 4,
  ),
  Award(
    id: 'reloj',
    name: 'Reloj de arena',
    hint: 'Una hora de cuentos en total',
    icon: Icons.hourglass_bottom,
    colors: const [Color(0xFF8EC5FF), Color(0xFF2F6DB5)],
    earned: (p) => p.minutes >= 60,
  ),
  Award(
    id: 'corazon_sabio',
    name: 'Corazón sabio',
    hint: 'Un cuento de cada una de las 6 enseñanzas',
    icon: Icons.favorite,
    colors: const [Color(0xFFFF9CB4), Color(0xFFC2416B)],
    earned: (p) => p.morals.length >= 6,
  ),
  Award(
    id: 'farol',
    name: 'Farol compartido',
    hint: 'Leer juntos 10 cuentos (con «Leemos juntos»)',
    icon: Icons.light,
    colors: const [Color(0xFFFFB86B), Color(0xFFB5641E)],
    earned: (p) => p.together >= 10,
  ),
  Award(
    id: 'viajero',
    name: 'Viajero de reinos',
    hint: 'Terminar cuentos de 3 paquetes distintos',
    icon: Icons.travel_explore,
    colors: const [Color(0xFFB79CFF), Color(0xFF5B3BB5)],
    earned: (p) => p.packs.length >= 3,
  ),
];

Award? awardById(String id) {
  for (final a in awards) {
    if (a.id == id) return a;
  }
  return null;
}

/// Lo que ha leído un niño. Solo vive en el teléfono.
class ChildProgress {
  ChildProgress({
    this.stories = 0,
    this.minutes = 0,
    this.together = 0,
    List<String>? days,
    Map<String, int>? morals,
    Set<String>? packs,
    Map<String, String>? earned,
  })  : days = days ?? [],
        morals = morals ?? {},
        packs = packs ?? {},
        earned = earned ?? {};

  factory ChildProgress.fromJson(Map<String, Object?> j) => ChildProgress(
        stories: (j['cuentos'] as num? ?? 0).toInt(),
        minutes: (j['minutos'] as num? ?? 0).toInt(),
        together: (j['juntos'] as num? ?? 0).toInt(),
        days: [
          for (final d in (j['noches'] as List<Object?>? ?? [])) d! as String
        ],
        morals: {
          for (final e
              in (j['ensenanzas'] as Map<String, Object?>? ?? {}).entries)
            e.key: (e.value! as num).toInt(),
        },
        packs: {
          for (final p in (j['paquetes'] as List<Object?>? ?? [])) p! as String
        },
        earned: {
          for (final e in (j['premios'] as Map<String, Object?>? ?? {}).entries)
            e.key: e.value! as String,
        },
      );

  /// Cuentos terminados.
  int stories;

  /// Minutos de cuento (aproximados por la longitud de cada cuento).
  int minutes;

  /// Cuentos terminados en «Leemos juntos».
  int together;

  /// Noches con cuento (`AAAA-MM-DD`, sin repetir, las últimas 400).
  final List<String> days;

  /// Enseñanza → cuentos terminados.
  final Map<String, int> morals;

  /// Paquetes con algún cuento terminado.
  final Set<String> packs;

  /// Premio → día en que se ganó.
  final Map<String, String> earned;

  /// Semanas (lunes a domingo) con cuento al menos 3 noches.
  int get storyWeeks {
    final perWeek = <String, int>{};
    for (final d in days) {
      final k = weekKey(DateTime.parse(d));
      perWeek[k] = (perWeek[k] ?? 0) + 1;
    }
    return perWeek.values.where((n) => n >= 3).length;
  }

  Map<String, Object?> toJson() => {
        'cuentos': stories,
        'minutos': minutes,
        'juntos': together,
        'noches': days,
        'ensenanzas': morals,
        'paquetes': packs.toList(),
        'premios': earned,
      };
}

/// El lunes de la semana de [d], como `AAAA-MM-DD`.
String weekKey(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
  return dayKey(monday);
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Minutos de un cuento por la longitud de su texto (≈ 850 caracteres por minuto en voz alta); al menos 1.
int minutesForText(int chars) {
  final m = (chars / 850).ceil();
  return m < 1 ? 1 : m;
}

/// El progreso de todos los niños de la familia (por id de niño; `''` = sin perfil).
class ReadingProgress extends ChangeNotifier {
  ReadingProgress(this._store);

  static const int maxDays = 400;

  final ShelfStore _store;
  Map<String, ChildProgress> _byChild = {};
  bool _loaded = false;

  ChildProgress of(String? childId) =>
      _byChild[childId ?? ''] ?? ChildProgress();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, Object?>;
        _byChild = {
          for (final e in j.entries)
            e.key: ChildProgress.fromJson(e.value! as Map<String, Object?>),
        };
      }
    } catch (_) {
      _byChild = {};
    }
    notifyListeners();
  }

  /// Anota un cuento terminado y devuelve los premios que se acaban de ganar (vacío casi siempre).
  Future<List<Award>> recordFinished({
    required String? childId,
    required String moralId,
    required String packId,
    required int minutes,
    bool together = false,
    DateTime? now,
  }) async {
    await load();
    final today = dayKey(now ?? DateTime.now());
    final p = _byChild.putIfAbsent(childId ?? '', ChildProgress.new);
    p.stories++;
    p.minutes += minutes;
    if (together) p.together++;
    if (!p.days.contains(today)) {
      p.days.add(today);
      if (p.days.length > maxDays) {
        p.days.removeRange(0, p.days.length - maxDays);
      }
    }
    p.morals[moralId] = (p.morals[moralId] ?? 0) + 1;
    p.packs.add(packId);
    final fresh = <Award>[];
    for (final a in awards) {
      if (!p.earned.containsKey(a.id) && a.earned(p)) {
        p.earned[a.id] = today;
        fresh.add(a);
      }
    }
    notifyListeners();
    await _save();
    return fresh;
  }

  /// Borra lo de un niño que ya no está.
  Future<void> removeChild(String childId) {
    _byChild.remove(childId);
    notifyListeners();
    return _save();
  }

  Future<void> clearAll() {
    _byChild = {};
    notifyListeners();
    return _save();
  }

  /// Lo que se guarda, tal cual (para «Ver mis datos»).
  Map<String, Object?> exportJson() => {
        for (final e in _byChild.entries) e.key: e.value.toJson(),
      };

  Future<void> _save() => _store.write(jsonEncode(exportJson()));
}

/// Guarda el progreso en las preferencias del teléfono.
class PrefsProgressStore implements ShelfStore {
  PrefsProgressStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'progress.v1';

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String json) => _prefs.setString(_key, json);
}
