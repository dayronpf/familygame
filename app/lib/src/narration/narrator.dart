import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Parte un texto en frases para narrarlas una a una (así se puede resaltar la que suena y
/// la voz respira entre frases). Las exclamaciones sueltas («¡CLANG!») se unen a la frase siguiente.
List<String> splitSentences(String text) {
  final raw = text
      .split(RegExp(r'(?<=[.!?…]»?)\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final out = <String>[];
  var carry = '';
  for (final s in raw) {
    final joined = carry.isEmpty ? s : '$carry $s';
    if (_words(joined) < 4) {
      carry = joined;
    } else {
      out.add(joined);
      carry = '';
    }
  }
  if (carry.isNotEmpty) {
    if (out.isEmpty) {
      out.add(carry);
    } else {
      out[out.length - 1] = '${out.last} $carry';
    }
  }
  return out;
}

int _words(String s) =>
    s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// Quien dice las frases en voz alta. [speak] termina cuando acaba la frase o cuando se llama a [stop].
abstract class Narrator {
  Future<void> speak(String sentence);
  Future<void> stop();
  Future<void> dispose() async {}
}

/// «Narra» esperando lo que tardaría una voz tranquila (sin sonido). Es el respaldo si el teléfono
/// no tiene voz en español, y lo que usan las pruebas.
class TimedNarrator implements Narrator {
  TimedNarrator({this.wordsPerSecond = 2.2, this.minSeconds = 1.2});

  final double wordsPerSecond;
  final double minSeconds;
  Completer<void>? _current;
  Timer? _timer;

  Duration durationOf(String sentence) {
    final secs = _words(sentence) / wordsPerSecond;
    return Duration(
        milliseconds: (secs < minSeconds ? minSeconds : secs) * 1000 ~/ 1);
  }

  @override
  Future<void> speak(String sentence) {
    final c = _current = Completer<void>();
    _timer = Timer(durationOf(sentence), () {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    final c = _current;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> dispose() => stop();
}

/// Voz del propio teléfono (Android/iOS, sin coste ni conexión). Si no hay voz o falla,
/// cae sola al narrador por tiempo para que el cuento siga avanzando.
class TtsNarrator implements Narrator {
  TtsNarrator({FlutterTts? tts, Narrator? fallback})
      : _tts = tts,
        _fallback = fallback ?? TimedNarrator();

  FlutterTts? _tts;
  final Narrator _fallback;
  Future<bool>? _ready;
  bool _broken = false;

  Future<bool> _init() async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.awaitSpeakCompletion(true);
      var ok = false;
      for (final lang in const ['es-ES', 'es-US', 'es-MX', 'es']) {
        final r = await tts.isLanguageAvailable(lang);
        if (r == true || r == 1) {
          await tts.setLanguage(lang);
          ok = true;
          break;
        }
      }
      if (!ok) return false;
      await tts.setSpeechRate(
          0.42); // algo más lenta que la normal: cuento para dormir
      await tts.setPitch(0.95);
      await tts.setVolume(1.0);
      return true;
    } catch (e) {
      debugPrint('Sin voz del sistema: $e');
      return false;
    }
  }

  @override
  Future<void> speak(String sentence) async {
    if (_broken) return _fallback.speak(sentence);
    final ready = await (_ready ??= _init());
    if (!ready) {
      _broken = true;
      return _fallback.speak(sentence);
    }
    try {
      final r = await _tts!.speak(sentence);
      if (r != 1 && r != null) throw StateError('speak devolvió $r');
    } catch (e) {
      debugPrint('La voz falló, sigo por tiempo: $e');
      _broken = true;
      return _fallback.speak(sentence);
    }
  }

  @override
  Future<void> stop() async {
    await _fallback.stop();
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
