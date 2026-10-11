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

  /// Volumen de la voz (0–1), para el fundido del temporizador de sueño. Se nota desde la siguiente frase.
  Future<void> setVolume(double volume) async {}
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
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() => stop();
}

/// Una voz que ofrece el teléfono (el wizard enseña unas pocas con nombre amigable).
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  /// Código técnico del motor (por ejemplo `es-es-x-eea-local`): nunca se enseña a la familia.
  final String name;
  final String locale;

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// Cómo suena el narrador: voz elegida (o la primera en español) y velocidad respecto a la normal.
class VoiceConfig {
  const VoiceConfig({this.voice, this.speed = 0.9});

  final TtsVoice? voice;

  /// 1.0 = velocidad normal del motor; los perfiles de edad van de 0.80 a 1.0 (ver `AgeProfile`).
  final double speed;
}

/// Lo justo que se usa del motor de voz del sistema. Existe para poder probar con uno falso que imite
/// cómo se comporta el de Android (ver `test/narrator_test.dart`).
abstract class TtsPort {
  Future<void> awaitSpeakCompletion(bool value);
  Future<bool> isLanguageAvailable(String language);
  Future<void> setLanguage(String language);
  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVolume(double volume);
  Future<List<TtsVoice>> voices();
  Future<void> setVoice(TtsVoice voice);

  /// Termina al acabar la frase. Devuelve `1` si se dijo entera y `0` si se **canceló** (con [stop]) o falló.
  Future<Object?> speak(String text);
  Future<void> stop();
}

/// El motor real (`flutter_tts`).
class FlutterTtsPort implements TtsPort {
  FlutterTtsPort([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> awaitSpeakCompletion(bool value) =>
      _tts.awaitSpeakCompletion(value);

  @override
  Future<bool> isLanguageAvailable(String language) async {
    final r = await _tts.isLanguageAvailable(language);
    return r == true || r == 1;
  }

  @override
  Future<void> setLanguage(String language) => _tts.setLanguage(language);

  @override
  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<void> setVolume(double volume) => _tts.setVolume(volume);

  @override
  Future<List<TtsVoice>> voices() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return const [];
    return [
      for (final v in raw)
        if (v is Map && v['name'] != null && v['locale'] != null)
          TtsVoice(name: '${v['name']}', locale: '${v['locale']}'),
    ];
  }

  @override
  Future<void> setVoice(TtsVoice voice) =>
      _tts.setVoice({'name': voice.name, 'locale': voice.locale});

  @override
  Future<Object?> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}

/// Voz del propio teléfono (Android/iOS, sin coste ni conexión). Si no hay voz en español, o si falla de verdad,
/// sigue por tiempo para que el cuento avance.
///
/// **Cancelar no es fallar.** En Android, `stop()` hace que el `speak()` que estaba esperando termine con `0`
/// (igual que un error). La versión anterior tomaba ese `0` por un fallo y daba la voz por rota *para siempre*:
/// bastaba pausar o adelantar una vez en mitad de una frase para que el resto del cuento quedara mudo.
/// Ahora cada orden de parar sube una «generación»; un `0` de una generación anterior es una cancelación
/// (se ignora), y un `0` de la actual es un fallo que se reintenta antes de seguir por tiempo.
class TtsNarrator implements Narrator {
  TtsNarrator({
    TtsPort? tts,
    Narrator? fallback,
    VoiceConfig config = const VoiceConfig(),
    this.retryDelay = const Duration(milliseconds: 250),
    this.language = 'es',
  })  : _port = tts,
        _fallback = fallback ?? TimedNarrator(),
        _config = config;

  TtsPort? _port;
  TtsPort get _tts => _port ??= FlutterTtsPort();
  final Narrator _fallback;
  final Duration retryDelay;

  /// Prefijo del idioma de los cuentos.
  final String language;
  VoiceConfig _config;
  Future<bool>? _ready;

  /// No hay voz en este idioma en el teléfono: ni se intenta más.
  bool _unavailable = false;
  int _gen = 0;
  int _failures = 0;

  /// Frases seguidas que fallaron aun tras reintentar: con tres se deja de probar hasta la próxima pausa.
  bool _gaveUp = false;

  static const int maxAttempts = 3;

  /// Velocidad que se manda al motor (0.5 es la normal en Android e iOS).
  static double rateFor(double speed) => (0.5 * speed).clamp(0.2, 0.7);

  Future<bool> _init() async {
    try {
      final tts = _tts;
      await tts.awaitSpeakCompletion(true);
      var ok = false;
      for (final lang in [
        for (final r in const ['ES', 'US', 'MX']) '$language-$r',
        language,
      ]) {
        if (await tts.isLanguageAvailable(lang)) {
          await tts.setLanguage(lang);
          ok = true;
          break;
        }
      }
      if (!ok) return false;
      final voice = _config.voice;
      if (voice != null) {
        try {
          await tts.setVoice(voice);
        } catch (_) {} // si esa voz ya no está, sigue con la de siempre
      }
      await tts.setSpeechRate(rateFor(_config.speed));
      await tts.setPitch(0.95);
      await tts.setVolume(_volume);
      return true;
    } catch (e) {
      debugPrint('Sin voz del sistema: $e');
      return false;
    }
  }

  /// Cambia voz o velocidad (se nota desde la próxima frase).
  Future<void> configure(VoiceConfig config) async {
    _config = config;
    if (_ready == null) return;
    final ok = await _ready!;
    if (!ok) return;
    try {
      final voice = config.voice;
      if (voice != null) {
        await _tts.setVoice(voice);
      }
      await _tts.setSpeechRate(rateFor(config.speed));
    } catch (_) {}
  }

  double _volume = 1.0;

  /// Volumen de la voz: se guarda para cuando el motor aún no esté listo y se aplica en cuanto lo está.
  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_ready == null) return;
    try {
      if (await _ready!) await _tts.setVolume(_volume);
    } catch (_) {}
  }

  /// Voces del teléfono en el idioma de los cuentos (para que la familia elija).
  Future<List<TtsVoice>> availableVoices() async {
    try {
      final all = await _tts.voices();
      return [
        for (final v in all)
          if (v.locale.toLowerCase().replaceAll('_', '-').startsWith(language))
            v,
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> speak(String sentence) async {
    if (_unavailable || _gaveUp) return _fallback.speak(sentence);
    final gen = _gen;
    // Un motor que no contesta no debe dejar el cuento colgado: a los 5 s se sigue por tiempo
    final ready = await (_ready ??=
        _init().timeout(const Duration(seconds: 5), onTimeout: () => false));
    if (gen != _gen) return; // se mandó parar mientras se preparaba
    if (!ready) {
      _unavailable = true;
      return _fallback.speak(sentence);
    }
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final r = await _tts.speak(sentence);
        // Cancelada a propósito (pausa, salto, cierre): no es un fallo
        if (gen != _gen) return;
        if (r == 1 || r == null) {
          _failures = 0;
          return;
        }
        debugPrint('La voz devolvió $r (intento ${attempt + 1})');
      } catch (e) {
        if (gen != _gen) return;
        debugPrint('La voz falló (intento ${attempt + 1}): $e');
      }
      await Future<void>.delayed(retryDelay);
      if (gen != _gen) return;
    }
    // Esta frase se sigue por tiempo; la voz se vuelve a intentar con la siguiente
    if (++_failures >= 3) _gaveUp = true;
    return _fallback.speak(sentence);
  }

  @override
  Future<void> stop() async {
    _gen++;
    _gaveUp =
        false; // una pausa o un salto es buen momento para volver a probar la voz
    _failures = 0;
    await _fallback.stop();
    try {
      await _port?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
