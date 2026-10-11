import 'package:caldero_app/src/audio/ambience.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/narration/playback.dart';
import 'package:caldero_app/src/player_support.dart';
import 'package:caldero_app/src/ui/screen_dimmer.dart';
import 'package:caldero_app/src/ui/sleep_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_tts.dart';

class _Narrator extends TimedNarrator {
  _Narrator() : super(wordsPerSecond: 1000, minSeconds: 0.001);
  final volumes = <double>[];
  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);
}

class _Ambience extends SilentAmbience {
  final levels = <double>[];
  int stops = 0;
  @override
  Future<void> setLevel(double level) async => levels.add(level);
  @override
  Future<void> stop() async => stops++;
}

class _Dimmer implements ScreenDimmer {
  final levels = <double>[];
  int restores = 0;
  @override
  Future<void> setLevel(double level) async => levels.add(level);
  @override
  Future<void> restore() async => restores++;
}

void main() {
  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('sleep-timer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Widget app(Widget button) => MaterialApp(home: Scaffold(body: button));

  group('el botón del temporizador', () {
    testWidgets('baja poco a poco los últimos segundos y solo entonces corta',
        (tester) async {
      final levels = <double>[];
      var expired = 0;
      await tester.pumpWidget(app(SleepTimerButton(
        minutesToDuration: (m) => Duration(seconds: m), // 10 minutos = 10 s
        fadeDuration: const Duration(seconds: 4),
        fadeTick: const Duration(seconds: 1),
        onFade: levels.add,
        onExpire: () => expired++,
      )));
      await pick(tester, 'Dormir en 10 minutos');
      await tester.pump(const Duration(milliseconds: 5900));
      expect(levels, isEmpty, reason: 'hasta los últimos 4 s no baja nada');
      await tester.pump(const Duration(milliseconds: 1200));
      expect(levels, [0.75]);
      expect(expired, 0);
      await tester.pump(const Duration(seconds: 3));
      expect(levels, [0.75, 0.5, 0.25, 0.0]);
      expect(expired, 1);
      // nunca sube, y llega a cero justo al cortar
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i], lessThan(levels[i - 1]));
      }
      await tester.pump(const Duration(seconds: 30));
      expect(expired, 1, reason: 'corta una sola vez');
    });

    testWidgets('un temporizador corto dedica a bajar la mitad de su tiempo',
        (tester) async {
      final levels = <double>[];
      await tester.pumpWidget(app(SleepTimerButton(
        minutesToDuration: (m) => Duration(seconds: m ~/ 5), // 10 min = 2 s
        fadeTick: const Duration(milliseconds: 500),
        onFade: levels.add,
        onExpire: () {},
      )));
      await pick(tester, 'Dormir en 10 minutos');
      await tester.pump(const Duration(milliseconds: 1600));
      expect(levels, [0.5], reason: 'la bajada empieza a la mitad (1 s)');
      await tester.pump(const Duration(seconds: 2));
      expect(levels.last, 0.0);
    });

    testWidgets('quitarlo a mitad del fundido devuelve volumen y brillo',
        (tester) async {
      final levels = <double>[];
      var cancelled = 0, expired = 0;
      await tester.pumpWidget(app(SleepTimerButton(
        minutesToDuration: (m) => Duration(seconds: m),
        fadeDuration: const Duration(seconds: 4),
        onFade: levels.add,
        onCancel: () => cancelled++,
        onExpire: () => expired++,
      )));
      await pick(tester, 'Dormir en 10 minutos');
      await tester.pump(const Duration(seconds: 8));
      expect(levels, [0.75, 0.5]);
      await pick(tester, 'Quitar temporizador');
      expect(cancelled, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(expired, 0);
      expect(levels, [0.75, 0.5], reason: 'ya no baja más');
    });

    testWidgets('quitarlo antes de que empiece no avisa de nada',
        (tester) async {
      var cancelled = 0;
      await tester.pumpWidget(app(SleepTimerButton(
        minutesToDuration: (m) => Duration(seconds: m),
        onCancel: () => cancelled++,
        onExpire: () {},
      )));
      await pick(tester, 'Dormir en 20 minutos');
      await pick(tester, 'Quitar temporizador');
      expect(cancelled, 0);
    });
  });

  group('SleepFade (voz, música y brillo a la vez)', () {
    late _Narrator narrator;
    late _Ambience ambience;
    late _Dimmer dimmer;
    late StoryPlayback playback;
    late SleepFade fade;

    setUp(() {
      narrator = _Narrator();
      ambience = _Ambience();
      dimmer = _Dimmer();
      playback = StoryPlayback(
        scenes: [PlayScene(text: 'Había una vez un caldero.', setup: null)],
        narrator: narrator,
      );
      fade = SleepFade(playback: playback, ambience: ambience, dimmer: dimmer);
    });

    tearDown(() => playback.dispose());

    test('el volumen baja más suave que el brillo (escala del oído)', () {
      fade.apply(0.5);
      expect(narrator.volumes.last, 0.25);
      expect(ambience.levels.last, 0.25);
      expect(dimmer.levels.last, 0.5);
      fade.apply(0.0);
      expect([narrator.volumes.last, ambience.levels.last, dimmer.levels.last],
          [0.0, 0.0, 0.0]);
    });

    test('al terminar calla la voz y la música; la pantalla sigue oscura',
        () async {
      playback.play();
      fade.apply(0.0);
      await fade.finish();
      expect(playback.playing, isFalse);
      expect(ambience.stops, 1);
      expect(dimmer.restores, 0);
    });

    test('al volver a reproducir se devuelve todo, y solo una vez', () async {
      fade.apply(0.2);
      await fade.reset();
      expect(narrator.volumes.last, 1.0);
      expect(ambience.levels.last, 1.0);
      expect(dimmer.restores, 1);
      await fade.reset(); // nada que devolver
      expect(dimmer.restores, 1);
    });

    test('salir de la pantalla devuelve el brillo aunque no se haya cumplido',
        () async {
      fade.apply(0.4);
      await fade.dispose();
      expect(dimmer.restores, 1);
    });
  });

  group('la voz del teléfono', () {
    test('el volumen elegido antes de que el motor esté listo se aplica',
        () async {
      final tts = FakeTts();
      final n = TtsNarrator(tts: tts);
      await n.setVolume(0.3); // aún no hay motor: se guarda
      final said = n.speak('Hola, cuento.');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(tts.volume, 0.3);
      await n.setVolume(0.1); // con el motor listo se aplica enseguida
      expect(tts.volume, 0.1);
      tts.finish();
      await said;
      await n.dispose();
    });
  });
}
