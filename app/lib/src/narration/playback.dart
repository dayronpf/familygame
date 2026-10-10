import 'dart:async';

import 'package:caldero_engine/caldero_engine.dart' show normalizeForVoice;
import 'package:flutter/foundation.dart';

import '../art/story_stage.dart';
import 'narrator.dart';

/// Una escena para reproducir: su texto (que se narra y, en el modo cine, se muestra) y su dibujo.
class PlayScene {
  PlayScene({required this.text, required this.setup, this.isMoral = false})
      : sentences = splitSentences(text);

  final String text;
  final StageSetup? setup;

  /// La última «escena» es la enseñanza dicha en voz alta.
  final bool isMoral;
  final List<String> sentences;
}

/// Reproduce un cuento escena a escena: narra cada frase, avanza solo al terminar y deja
/// pausar, saltar y volver. Es lo que mueve el modo cine y el modo holograma.
class StoryPlayback extends ChangeNotifier {
  StoryPlayback({
    required this.scenes,
    required this.narrator,
    this.title,
    this.gap = const Duration(milliseconds: 700),
    this.narrate = true,
  });

  final List<PlayScene> scenes;
  final Narrator narrator;
  final String? title;

  /// Respiro entre escenas (deja ver el cambio de dibujo).
  final Duration gap;

  /// Si es `false` no se oye la voz y cada frase espera lo que tardaría en decirse.
  bool narrate;

  int _scene = 0;
  int _sentence = 0;
  bool _playing = false;
  bool _finished = false;
  int _run = 0; // cada reproducción nueva invalida a la anterior
  bool _disposed = false;
  Timer? _gapTimer;
  Completer<void>? _gapDone;

  int get scene => _scene;
  int get sentence => _sentence;
  bool get playing => _playing;
  bool get finished => _finished;
  PlayScene get current => scenes[_scene];

  /// Texto de la frase que suena ahora.
  String get currentSentence => current.sentences.isEmpty
      ? current.text
      : current.sentences[_sentence.clamp(0, current.sentences.length - 1)];

  void play() {
    if (_playing || scenes.isEmpty) return;
    if (_finished) {
      _scene = 0;
      _sentence = 0;
      _finished = false;
    }
    _playing = true;
    notifyListeners();
    unawaited(_loop(++_run));
  }

  Future<void> pause() async {
    _resume = false;
    _jump++; // si había un salto esperando, ya no reanuda
    if (!_playing) return;
    _playing = false;
    _run++;
    _cancelBreath();
    notifyListeners();
    await narrator.stop();
  }

  Future<void> toggle() => _playing ? pause() : Future.sync(play);

  int _jump = 0; // el último salto es el que manda
  bool _resume = false; // había voz cuando se pidió saltar

  /// Va a la escena [i] y, si estaba sonando, sigue desde ahí.
  ///
  /// El estado cambia **antes** de esperar a que la voz pare: así varios saltos seguidos y rápidos («adelantar»
  /// cinco veces) se suman en vez de partir todos de la misma escena, y solo el último vuelve a hablar.
  Future<void> goTo(int i) async {
    _resume = _resume || _playing;
    final token = ++_jump;
    _run++;
    _cancelBreath();
    _scene = i.clamp(0, scenes.length - 1);
    _sentence = 0;
    _finished = false;
    _playing = false;
    notifyListeners();
    await narrator.stop();
    if (token != _jump || _disposed) return;
    final resume = _resume;
    _resume = false;
    if (resume) play();
  }

  Future<void> next() => goTo(_scene + 1);
  Future<void> previous() => goTo(_scene - 1);

  /// Lo que se lee en pantalla (`texto_pantalla`) y lo que se dice (`texto_voz`) son distintos: a la voz le llega
  /// la frase ya normalizada (sin comillas «», sin «Fiuuu», con las cifras en palabras…).
  Future<void> _say(String s) {
    final voice = normalizeForVoice(s);
    if (voice.isEmpty) return Future.value();
    return narrate ? narrator.speak(voice) : TimedNarrator().speak(voice);
  }

  bool _alive(int run) => !_disposed && run == _run;

  /// Espera [gap] (cancelable: al pausar, saltar o cerrar se interrumpe en el acto).
  Future<void> _breathe() {
    final c = _gapDone = Completer<void>();
    _gapTimer = Timer(gap, () {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  void _cancelBreath() {
    _gapTimer?.cancel();
    final c = _gapDone;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> _loop(int run) async {
    if (run == _run && _scene == 0 && _sentence == 0) {
      final t = title;
      if (t != null && t.isNotEmpty) {
        await _say(t);
        if (!_alive(run)) return;
        await _breathe();
        if (!_alive(run)) return;
      }
    }
    while (_alive(run) && _scene < scenes.length) {
      final sc = scenes[_scene];
      while (_alive(run) && _sentence < sc.sentences.length) {
        notifyListeners();
        await _say(sc.sentences[_sentence]);
        if (!_alive(run)) return;
        _sentence++;
      }
      if (!_alive(run)) return;
      if (_scene == scenes.length - 1) break;
      await _breathe();
      if (!_alive(run)) return;
      _scene++;
      _sentence = 0;
      notifyListeners();
    }
    if (!_alive(run)) return;
    _playing = false;
    _finished = true;
    _sentence =
        scenes.last.sentences.isEmpty ? 0 : scenes.last.sentences.length - 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    _cancelBreath();
    narrator.stop();
    super.dispose();
  }
}
