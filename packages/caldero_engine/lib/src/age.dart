/// Perfiles de edad: para quién es un cuento (longitud, oraciones, ritmo de la voz). Las cifras son las de
/// `docs/18-voz-edades-y-wizard.md` (propuesta a validar con familias): agrupan edades que comparten tipo de
/// narrativa y tiempo de lectura antes de dormir.
library;

import 'models.dart';

class AgeProfile {
  const AgeProfile({
    required this.id,
    required this.label,
    required this.minAge,
    required this.maxAge,
    required this.minWords,
    required this.maxWords,
    required this.minMinutes,
    required this.maxMinutes,
    required this.minSentence,
    required this.maxSentence,
    required this.speed,
    required this.blurb,
  });

  /// `2-3`, `4-5`, `6-8` o `9-12`: es lo que declaran las premisas en `ages` y lo que guardan los ajustes.
  final String id;
  final String label;
  final int minAge;
  final int maxAge;
  final int minWords;
  final int maxWords;
  final int minMinutes;
  final int maxMinutes;

  /// Longitud típica de la oración, en palabras (media del cuento).
  final int minSentence;
  final int maxSentence;

  /// Velocidad de la voz respecto a la normal (1.0).
  final double speed;

  /// Qué cambia, en una línea (se enseña en el wizard).
  final String blurb;

  bool coversAge(int years) => years >= minAge && years <= maxAge;

  static const List<AgeProfile> all = [
    AgeProfile(
      id: '2-3',
      label: '2–3 años',
      minAge: 2,
      maxAge: 3,
      minWords: 150,
      maxWords: 300,
      minMinutes: 2,
      maxMinutes: 3,
      minSentence: 4,
      maxSentence: 8,
      speed: 0.80,
      blurb: 'Cuentos muy cortos, con repetición y final feliz enseguida',
    ),
    AgeProfile(
      id: '4-5',
      label: '4–5 años',
      minAge: 4,
      maxAge: 5,
      minWords: 300,
      maxWords: 600,
      minMinutes: 4,
      maxMinutes: 6,
      minSentence: 6,
      maxSentence: 10,
      speed: 0.85,
      blurb: 'Un problema sencillo que se resuelve, sin peligro de verdad',
    ),
    AgeProfile(
      id: '6-8',
      label: '6–8 años',
      minAge: 6,
      maxAge: 8,
      minWords: 600,
      maxWords: 1200,
      minMinutes: 6,
      maxMinutes: 10,
      minSentence: 8,
      maxSentence: 14,
      speed: 0.90,
      blurb: 'Aventuras con varios personajes y un susto suave',
    ),
    AgeProfile(
      id: '9-12',
      label: '9–12 años',
      minAge: 9,
      maxAge: 12,
      minWords: 1200,
      maxWords: 2000,
      minMinutes: 10,
      maxMinutes: 15,
      minSentence: 10,
      maxSentence: 20,
      speed: 1.00,
      blurb: 'Tramas con giros y personajes que cambian',
    ),
  ];

  static const String defaultId = '4-5';

  static AgeProfile? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static AgeProfile forAge(int years) => all.firstWhere(
        (p) => p.coversAge(years),
        orElse: () => years < 2 ? all.first : all.last,
      );

  /// Posición del perfil (0 = 2–3 … 3 = 9–12), para medir cercanía.
  int get order => all.indexOf(this);
}

/// Lo que mide un cuento contra un perfil.
class StoryMetrics {
  const StoryMetrics({
    required this.words,
    required this.sentences,
    required this.avgSentence,
    required this.maxSentence,
    required this.minutes,
  });

  final int words;
  final int sentences;
  final double avgSentence;
  final int maxSentence;

  /// Minutos leídos con la voz del perfil (unas 110 palabras por minuto a velocidad 1.0).
  final double minutes;

  /// Si [p] sirve para este cuento. [tolerance] deja un margen en las palabras (el reparto de cada versión varía).
  bool fits(AgeProfile p, {double tolerance = 0.1}) =>
      words >= p.minWords * (1 - tolerance) &&
      words <= p.maxWords * (1 + tolerance) &&
      avgSentence >= p.minSentence &&
      avgSentence <= p.maxSentence;
}

/// Mide un cuento (el texto de las escenas más la enseñanza dicha al final).
StoryMetrics measureText(List<String> texts, {double speed = 1.0}) {
  var words = 0;
  final lengths = <int>[];
  for (final t in texts) {
    for (final s in t.split(RegExp(r'(?<=[.!?…»])\s+'))) {
      final n = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (n == 0) continue;
      words += n;
      lengths.add(n);
    }
  }
  final avg = lengths.isEmpty ? 0.0 : words / lengths.length;
  return StoryMetrics(
    words: words,
    sentences: lengths.length,
    avgSentence: avg,
    maxSentence: lengths.isEmpty ? 0 : lengths.reduce((a, b) => a > b ? a : b),
    minutes: words / (110 * speed),
  );
}

StoryMetrics measureStory(Story story, {double speed = 1.0}) => measureText(
      [for (final s in story.scenes) s.text],
      speed: speed,
    );

extension AgePremises on Pack {
  /// Edades (ids de perfil) para las que hay cuentos en este pack.
  Set<String> get agesWithStories => {
        for (final p in premises)
          if (p.ages.isEmpty) ...AgeProfile.all.map((a) => a.id) else ...p.ages,
      };

  /// El perfil para el que de verdad hay cuentos más cercano al pedido: el mismo si hay, y si no el más próximo
  /// (los vecinos más pequeños primero: ante la duda, un cuento más sencillo y tranquilo). `null` si no se pide edad.
  String? resolveAge(String? requested) {
    final want = AgeProfile.byId(requested);
    if (want == null) return null;
    final have = agesWithStories;
    if (have.contains(want.id)) return want.id;
    AgeProfile? best;
    var bestDist = 1 << 30;
    for (final p in AgeProfile.all) {
      if (!have.contains(p.id)) continue;
      final d = (p.order - want.order).abs();
      if (d < bestDist || (d == bestDist && p.order < best!.order)) {
        best = p;
        bestDist = d;
      }
    }
    return best?.id;
  }
}
