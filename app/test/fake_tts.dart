import 'dart:async';

import 'package:caldero_app/src/narration/narrator.dart';

/// Motor de voz de mentira que imita lo que hace `flutter_tts` en Android (leído en su código):
/// con `awaitSpeakCompletion`, `speak()` espera a que acabe la frase y devuelve 1; `stop()` hace que el `speak()`
/// pendiente devuelva **0**; y un `speak()` mientras aún suena otra frase devuelve 0 en el acto.
class FakeTts implements TtsPort {
  final spoken = <String>[];
  Completer<Object?>? _pending;
  bool speaking = false;
  int failNext =
      0; // cuántos speak() devolver 0 «de verdad» (motor ocupado o con error)
  bool hasSpanish = true;
  int stops = 0;
  double? rate;
  double? volume;
  TtsVoice? voice;
  List<TtsVoice> installed = const [];

  @override
  Future<void> awaitSpeakCompletion(bool value) async {}
  @override
  Future<bool> isLanguageAvailable(String language) async => hasSpanish;
  @override
  Future<void> setLanguage(String language) async {}
  @override
  Future<void> setSpeechRate(double r) async => rate = r;
  @override
  Future<void> setPitch(double pitch) async {}
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<List<TtsVoice>> voices() async => installed;
  @override
  Future<void> setVoice(TtsVoice v) async => voice = v;

  @override
  Future<Object?> speak(String text) {
    spoken.add(text);
    if (failNext > 0) {
      failNext--;
      return Future.value(0);
    }
    if (speaking) return Future.value(0);
    speaking = true;
    return (_pending = Completer<Object?>()).future;
  }

  /// La frase que suena termina sola.
  void finish() {
    speaking = false;
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(1);
  }

  @override
  Future<void> stop() async {
    stops++;
    speaking = false;
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(0);
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

TtsNarrator narratorOver(FakeTts tts) => TtsNarrator(
      tts: tts,
      retryDelay: const Duration(milliseconds: 5),
      fallback: TimedNarrator(wordsPerSecond: 1000, minSeconds: 0.01),
    );
