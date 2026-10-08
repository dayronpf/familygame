import 'dart:convert';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cuento terminado que aún no se ha valorado (para preguntar a la mañana siguiente).
/// La etiqueta se queda SOLO en el teléfono; nunca se envía.
class PendingStory {
  PendingStory({required this.recipe, required this.label, required this.day});

  factory PendingStory.fromJson(Map<String, Object?> j) => PendingStory(
        recipe: StoryRecipe.fromJson(j['recipe']! as Map<String, Object?>),
        label: j['label']! as String,
        day: j['day']! as String,
      );

  final StoryRecipe recipe;
  final String label;
  final String day;

  Map<String, Object?> toJson() =>
      {'recipe': recipe.toJson(), 'label': label, 'day': day};
}

/// Almacenamiento local de la cola de envío, las valoraciones pendientes y el permiso.
abstract class FeedbackStore {
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool value);
  Future<List<Map<String, Object?>>> readQueue();
  Future<void> writeQueue(List<Map<String, Object?>> events);
  Future<List<PendingStory>> readPending();
  Future<void> writePending(List<PendingStory> items);
  Future<int> readRetryAt();
  Future<void> writeRetryAt(int epochMs, int failures);
  Future<int> readFailures();
}

/// En memoria (pruebas).
class MemoryFeedbackStore implements FeedbackStore {
  bool enabled = true;
  List<Map<String, Object?>> queue = [];
  List<PendingStory> pending = [];
  int retryAt = 0;
  int failures = 0;

  @override
  Future<bool> readEnabled() async => enabled;
  @override
  Future<void> writeEnabled(bool value) async => enabled = value;
  @override
  Future<List<Map<String, Object?>>> readQueue() async => List.of(queue);
  @override
  Future<void> writeQueue(List<Map<String, Object?>> events) async =>
      queue = List.of(events);
  @override
  Future<List<PendingStory>> readPending() async => List.of(pending);
  @override
  Future<void> writePending(List<PendingStory> items) async =>
      pending = List.of(items);
  @override
  Future<int> readRetryAt() async => retryAt;
  @override
  Future<void> writeRetryAt(int epochMs, int failures) async {
    retryAt = epochMs;
    this.failures = failures;
  }

  @override
  Future<int> readFailures() async => failures;
}

/// Persistente (`shared_preferences`). Volumen pequeño: como mucho unos cientos de eventos.
class PrefsFeedbackStore implements FeedbackStore {
  PrefsFeedbackStore(this._prefs);

  final SharedPreferences _prefs;

  static const _enabled = 'feedback.enabled';
  static const _queue = 'feedback.queue';
  static const _pending = 'feedback.pending';
  static const _retryAt = 'feedback.retryAt';
  static const _failures = 'feedback.failures';

  @override
  Future<bool> readEnabled() async => _prefs.getBool(_enabled) ?? true;
  @override
  Future<void> writeEnabled(bool value) => _prefs.setBool(_enabled, value);

  @override
  Future<List<Map<String, Object?>>> readQueue() async => [
        for (final s in _prefs.getStringList(_queue) ?? const <String>[])
          jsonDecode(s) as Map<String, Object?>,
      ];
  @override
  Future<void> writeQueue(List<Map<String, Object?>> events) =>
      _prefs.setStringList(_queue, [for (final e in events) jsonEncode(e)]);

  @override
  Future<List<PendingStory>> readPending() async => [
        for (final s in _prefs.getStringList(_pending) ?? const <String>[])
          PendingStory.fromJson(jsonDecode(s) as Map<String, Object?>),
      ];
  @override
  Future<void> writePending(List<PendingStory> items) => _prefs
      .setStringList(_pending, [for (final p in items) jsonEncode(p.toJson())]);

  @override
  Future<int> readRetryAt() async => _prefs.getInt(_retryAt) ?? 0;
  @override
  Future<void> writeRetryAt(int epochMs, int failures) async {
    await _prefs.setInt(_retryAt, epochMs);
    await _prefs.setInt(_failures, failures);
  }

  @override
  Future<int> readFailures() async => _prefs.getInt(_failures) ?? 0;
}
