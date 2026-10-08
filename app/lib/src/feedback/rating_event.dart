import 'dart:math';

import 'package:caldero_engine/caldero_engine.dart';

/// Versión de la app que se informa junto a la valoración (la verifica una prueba contra el pubspec).
const String appVersion = '0.1.0';

/// Versión del formato del evento (`schema` en el JSON).
const int ratingSchema = 1;

/// Generador de identificadores únicos (UUID v4) para que el servidor no duplique envíos reintentados.
String newEventId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0F) | 0x40; // versión 4
  b[8] = (b[8] & 0x3F) | 0x80; // variante RFC 4122
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Fecha (UTC) sin hora: `2026-10-08`. Se envía solo el día, nunca el instante exacto.
String dayOf(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}';
}

/// **Lo único que la app envía al servidor**: una valoración de 1 a 5 de un cuento identificado
/// por su receta. No lleva nombres, texto, dispositivo, usuario, IP ni hora exacta.
class RatingEvent {
  RatingEvent({
    required this.id,
    required this.recipe,
    required this.rating,
    required this.day,
    this.app = appVersion,
  }) {
    if (rating < 1 || rating > 5) {
      throw RangeError.range(rating, 1, 5, 'rating');
    }
  }

  factory RatingEvent.fromJson(Map<String, Object?> j) => RatingEvent(
        id: j['id']! as String,
        recipe: StoryRecipe.fromJson(j['recipe']! as Map<String, Object?>),
        rating: (j['rating']! as num).toInt(),
        day: j['day']! as String,
        app: j['app']! as String,
      );

  final String id;
  final StoryRecipe recipe;
  final int rating;
  final String day;
  final String app;

  Map<String, Object?> toJson() => {
        'id': id,
        'schema': ratingSchema,
        'rating': rating,
        'day': day,
        'app': app,
        'recipe': recipe.toJson(),
      };
}
