import 'dart:async';

import 'package:caldero_engine/caldero_engine.dart'
    show StoryChoice, normalizeForVoice;
import 'package:flutter/foundation.dart';

import '../art/story_stage.dart';
import 'narrator.dart';

/// Una escena para reproducir: su texto (que se narra y, en el modo cine, se muestra) y su dibujo.
class PlayScene {
  PlayScene({
    required this.text,
    required this.setup,
    this.isMoral = false,
    this.choice,
    this.pickedOption,
  }) : sentences = splitSentences(text);

  final String text;
  final StageSetup? setup;

  /// La pregunta que sigue a esta escena y la opción elegida (`null` = aún sin responder).
  final StoryChoice? choice;
  final String? pickedOption;

  bool get needsAnswer => choice != null && pickedOption == null;

  PlayScene answered(String optionId) => PlayScene(
        text: text,
        setup: setup,
        isMoral: isMoral,
        choice: choice,
        pickedOption: optionId,
      );

  /// La última «escena» es la enseñanza dicha en voz alta.
  final bool isMoral;
  final List<String> sentences;
}

/// Reproduce un cuento escena a escena: narra cada frase, avanza solo al terminar y deja
/// pausar, saltar y volver. Es lo que mueve el modo cine y el modo holograma.
class StoryPlayback extends ChangeNotifier {
  StoryPlayback({
    required List<PlayScene> scenes,
    required this.narrator,
    this.title,
    this.gap = const Duration(milliseconds: 700),
    this.narrate = true,
    this.resolve,
    this.firstWait = const Duration(seconds: 20),
    this.secondWait = const Duration(seconds: 15),
  }) : scenes = List.of(scenes);

  /// Las escenas; crece cuando el niño responde una pregunta (el resto del cuento depende de su respuesta).
  final List<PlayScene> scenes;
  final Narrator narrator;
  final String? title;

  /// Sigue el cuento con la opción elegida (`null` = que elija la app) y devuelve **todas** las escenas que
  /// vienen después de la pregunta (incluida la enseñanza final). Sin él, no se pregunta nada.
  final Future<List<PlayScene>> Function(String? optionId)? resolve;

  /// Cuánto se espera una respuesta antes de repetir las opciones, y cuánto más antes de elegir por el niño.
  final Duration firstWait, secondWait;

  /// `false` (temporizador de sueño armado) = no se hace ninguna pausa: se elige sola, sin avisar.
  bool asks = true;

  StoryChoice? _asking;
  int? _speakingOption;
  Completer<String?>? _answer;
  Timer? _askTimer;

  /// La pregunta que espera respuesta ahora (las tarjetas se ven mientras no sea `null`).
  StoryChoice? get asking => _asking;

  /// Posición de la opción que la voz está diciendo ahora (para iluminarla).
  int? get speakingOption => _speakingOption;

  /// «Elige por nosotros»: la app contesta por su cuenta.
  void chooseForMe() {
    final a = _answer;
    if (a != null && !a.isCompleted) {
      a.complete(_autoPick);
      narrator.stop();
    }
  }

  /// El niño (o el adulto) toca una opción.
  void choose(String optionId) {
    final a = _answer;
    if (a != null && !a.isCompleted) {
      a.complete(optionId);
      narrator
          .stop(); // si la voz estaba nombrando las opciones, se calla en el acto
    }
  }

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
    _cancelAsk();
    notifyListeners();
    await narrator.stop();
  }

  Future<void> toggle() => _playing ? pause() : Future.sync(play);

  /// Volumen de la voz (fundido del temporizador de sueño).
  Future<void> setVolume(double volume) => narrator.setVolume(volume);

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
    _cancelAsk();
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

  void _cancelAsk() {
    _askTimer?.cancel();
    final a = _answer;
    if (a != null && !a.isCompleted) a.complete(null);
    if (_asking != null) {
      _asking = null;
      _speakingOption = null;
    }
  }

  /// Espera [d] o hasta que haya respuesta.
  Future<void> _waitAnswer(Duration d) {
    final a = _answer!;
    final c = Completer<void>();
    _askTimer = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    a.future.whenComplete(() {
      _askTimer?.cancel();
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  /// Hace la pregunta: la voz dice la pregunta y las opciones (iluminando cada tarjeta), espera, repite las
  /// opciones y, si nadie contesta, elige la app («Esta vez elijo yo»). Devuelve la opción o `null` si se
  /// canceló (pausa, salto, cierre). Con [asks] apagado no hay pausa ni aviso: elige la app en el acto.
  Future<String?> _ask(int run, StoryChoice q) async {
    if (!asks) return _autoPick;
    final a = _answer = Completer<String?>();
    _asking = q;
    _speakingOption = null;
    notifyListeners();

    bool open() => !a.isCompleted && _alive(run);

    Future<void> readOptions() async {
      for (var i = 0; i < q.options.length && open(); i++) {
        _speakingOption = i;
        notifyListeners();
        await _say(q.options[i].label);
      }
      _speakingOption = null;
      if (open()) notifyListeners();
    }

    await _say(q.ask);
    if (open()) await readOptions();
    if (open()) await _waitAnswer(firstWait);
    if (open()) {
      await readOptions(); // repite solo las opciones
      if (open()) await _waitAnswer(secondWait);
    }
    if (open()) {
      await _say('Esta vez elijo yo.');
      if (open()) a.complete(_autoPick);
    }
    final answer = await a.future;
    _asking = null;
    _speakingOption = null;
    if (_alive(run)) notifyListeners();
    return answer;
  }

  /// Marca de «elige la app» al resolver: el reproductor no conoce las opciones, las conoce quien resuelve.
  static const String? _autoPick = null;

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
      if (resolve != null && sc.needsAnswer) {
        final q = sc.choice!;
        final picked = await _ask(run, q);
        if (!_alive(run)) return;
        final rest = await resolve!(picked);
        if (!_alive(run)) return;
        scenes
          ..[_scene] = sc.answered(picked ?? '')
          ..removeRange(_scene + 1, scenes.length)
          ..addAll(rest);
        notifyListeners();
      }
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
    _cancelAsk();
    narrator.stop();
    super.dispose();
  }
}
