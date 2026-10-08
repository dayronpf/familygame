import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/foundation.dart';

import 'feedback_store.dart';
import 'feedback_transport.dart';
import 'rating_event.dart';

/// Resultado de intentar vaciar la cola.
enum FlushResult {
  /// Nada que enviar.
  empty,

  /// Se envió todo.
  sent,

  /// Falló: se conserva y se reintentará.
  failed,

  /// Aún no toca reintentar (espera por fallos anteriores).
  waiting,

  /// El usuario desactivó el envío.
  disabled,

  /// No hay servidor configurado: las valoraciones esperan en el teléfono.
  noServer,
}

/// Recoge las valoraciones y las envía cuando se puede.
///
/// Principios: **nunca** bloquea ni molesta al lector, funciona sin conexión, no repite envíos
/// (cada evento lleva un id único) y solo envía [RatingEvent].
class FeedbackService {
  FeedbackService({
    required this.store,
    this.transport,
    DateTime Function()? now,
    String Function()? idGenerator,
  })  : _now = now ?? DateTime.now,
        _newId = idGenerator ?? newEventId;

  final FeedbackStore store;

  /// `null` = todavía no hay backend.
  final FeedbackTransport? transport;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Máximo de valoraciones guardadas sin enviar (se descartan las más antiguas).
  static const int maxQueue = 200;

  /// Valoraciones por petición.
  static const int batchSize = 50;

  /// Cuentos terminados sin valorar que se recuerdan, y cuántos días valen.
  static const int maxPending = 3;
  static const int pendingDays = 3;

  /// Espera entre reintentos: 1 min, 2, 4… hasta 6 h.
  static const Duration baseBackoff = Duration(minutes: 1);
  static const Duration maxBackoff = Duration(hours: 6);

  bool _flushing = false;

  /// Sube cada vez que cambia la lista de cuentos pendientes de valorar (la pantalla de inicio escucha).
  final ValueNotifier<int> pendingChanges = ValueNotifier(0);

  Future<bool> get enabled => store.readEnabled();

  Future<void> setEnabled(bool value) async {
    await store.writeEnabled(value);
    if (!value) {
      // Al desactivar se borra todo lo que estaba esperando para enviarse.
      await store.writeQueue(const []);
      await store.writePending(const []);
      pendingChanges.value++;
    }
  }

  Future<int> queuedCount() async => (await store.readQueue()).length;

  /// Registra la valoración de un cuento. Devuelve `false` si el envío está desactivado.
  Future<bool> rate(StoryRecipe recipe, int rating) async {
    if (!await enabled) return false;
    final event = RatingEvent(
        id: _newId(), recipe: recipe, rating: rating, day: dayOf(_now()));
    final queue = await store.readQueue()
      ..add(event.toJson());
    while (queue.length > maxQueue) {
      queue.removeAt(0);
    }
    await store.writeQueue(queue);
    await _forget(recipe);
    return true;
  }

  // ---------------------------------------------------------------- pendientes

  /// Recuerda un cuento que se leyó hasta el final pero no se valoró.
  Future<void> rememberPending(StoryRecipe recipe, String label) async {
    if (!await enabled) return;
    final items = await store.readPending();
    items.removeWhere((p) => _same(p.recipe, recipe));
    items.add(PendingStory(recipe: recipe, label: label, day: dayOf(_now())));
    while (items.length > maxPending) {
      items.removeAt(0);
    }
    await store.writePending(items);
    pendingChanges.value++;
  }

  /// El cuento pendiente más reciente que aún vale la pena preguntar (o `null`).
  Future<PendingStory?> nextPending() async {
    if (!await enabled) return null;
    final items = await store.readPending();
    final today = DateTime.parse(dayOf(_now()));
    final fresh = [
      for (final p in items)
        if (today.difference(DateTime.parse(p.day)).inDays <= pendingDays) p,
    ];
    if (fresh.length != items.length) await store.writePending(fresh);
    return fresh.isEmpty ? null : fresh.last;
  }

  /// «Ahora no»: se deja de preguntar por ese cuento.
  Future<void> dismissPending(StoryRecipe recipe) => _forget(recipe);

  Future<void> _forget(StoryRecipe recipe) async {
    final items = await store.readPending();
    final kept = items.where((p) => !_same(p.recipe, recipe)).toList();
    if (kept.length != items.length) {
      await store.writePending(kept);
      pendingChanges.value++;
    }
  }

  static bool _same(StoryRecipe a, StoryRecipe b) =>
      a.packId == b.packId &&
      a.packVersion == b.packVersion &&
      a.seed == b.seed &&
      a.valueId == b.valueId;

  // -------------------------------------------------------------------- envío

  /// Intenta enviar lo que haya en la cola. Es seguro llamarlo muchas veces.
  Future<FlushResult> flush({bool force = false}) async {
    if (_flushing) return FlushResult.waiting;
    _flushing = true;
    try {
      if (!await enabled) return FlushResult.disabled;
      final t = transport;
      if (t == null) return FlushResult.noServer;
      var queue = await store.readQueue();
      if (queue.isEmpty) return FlushResult.empty;
      if (!force && _now().millisecondsSinceEpoch < await store.readRetryAt()) {
        return FlushResult.waiting;
      }
      while (queue.isNotEmpty) {
        final batch = queue.take(batchSize).toList();
        final outcome = await t.send(batch);
        if (outcome == SendOutcome.retryLater) {
          final failures = await store.readFailures() + 1;
          final wait = _backoff(failures);
          await store.writeRetryAt(
              _now().add(wait).millisecondsSinceEpoch, failures);
          return FlushResult.failed;
        }
        queue = queue.skip(batch.length).toList();
        await store.writeQueue(queue);
      }
      await store.writeRetryAt(0, 0);
      return FlushResult.sent;
    } finally {
      _flushing = false;
    }
  }

  static Duration _backoff(int failures) {
    final ms = baseBackoff.inMilliseconds * (1 << (failures - 1).clamp(0, 20));
    return Duration(milliseconds: ms.clamp(0, maxBackoff.inMilliseconds));
  }
}
