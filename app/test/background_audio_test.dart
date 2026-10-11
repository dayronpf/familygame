import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_app/src/audio/ambience.dart';
import 'package:caldero_app/src/audio/background_audio.dart';
import 'package:caldero_app/src/audio_only_page.dart';
import 'package:caldero_app/src/cinema_page.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/narration/playback.dart';
import 'package:caldero_app/src/ui/screen_dimmer.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// El servicio de mentira: apunta lo que se le pide.
class _Service implements BackgroundAudio {
  @override
  void Function(BackgroundAction action)? onAction;
  final calls = <String>[];

  @override
  Future<void> start(String title, {required bool playing}) async =>
      calls.add('start:$title:$playing');
  @override
  Future<void> setPlaying(bool playing) async => calls.add('playing:$playing');
  @override
  Future<void> stop() async => calls.add('stop');

  /// Lo que haría el botón de la notificación.
  void press(BackgroundAction a) => onAction?.call(a);
}

class _Voice implements Narrator {
  @override
  Future<void> speak(String sentence) =>
      Future<void>.delayed(const Duration(milliseconds: 50));
  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
}

class _Music extends SilentAmbience {}

class _Screen implements ScreenDimmer {
  @override
  Future<void> setLevel(double level) async {}
  @override
  Future<void> restore() async {}
}

Story _story() {
  final pack = Pack.fromJson(
    jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
        as Map<String, Object?>,
  );
  return StoryEngine(pack).generate(const StoryOptions(seed: 4, age: '4-5'));
}

StoryPlayback _playback() => StoryPlayback(
      scenes: [PlayScene(text: 'Hola mundo de los cuentos.', setup: null)],
      narrator: _Voice(),
      gap: Duration.zero,
    );

void main() {
  group('BackgroundSession', () {
    test('avisa al servicio de si suena o está en pausa', () async {
      final pb = _playback();
      final svc = _Service();
      final s = BackgroundSession(playback: pb, audio: svc, title: 'Mi cuento');
      await s.start(playing: false);
      expect(svc.calls, ['start:Mi cuento:false']);
      pb.play();
      expect(svc.calls.last, 'playing:true');
      await pb.pause();
      expect(svc.calls.last, 'playing:false');
      // Un aviso por cambio, no uno por frase.
      final n = svc.calls.length;
      pb.notifyListeners();
      expect(svc.calls.length, n);
      await s.close();
      pb.dispose();
    });

    test('los botones de la notificación dirigen el cuento', () async {
      final pb = _playback();
      final svc = _Service();
      var stopped = 0;
      final s = BackgroundSession(
          playback: pb, audio: svc, title: 'T', onStopped: () => stopped++);
      await s.start(playing: false);
      svc.press(BackgroundAction.play);
      expect(pb.playing, isTrue);
      svc.press(BackgroundAction.pause);
      await Future<void>.delayed(Duration.zero);
      expect(pb.playing, isFalse);
      svc.press(BackgroundAction.play);
      svc.press(BackgroundAction.stop);
      await Future<void>.delayed(Duration.zero);
      expect(pb.playing, isFalse);
      expect(stopped, 1);
      expect(svc.calls.last, 'stop', reason: 'parar quita la notificación');
      pb.dispose();
    });

    test('cerrar es idempotente y deja de escuchar', () async {
      final pb = _playback();
      final svc = _Service();
      final s = BackgroundSession(playback: pb, audio: svc, title: 'T');
      await s.start(playing: false);
      await s.close();
      await s.close();
      pb.play();
      expect(svc.calls.where((c) => c == 'stop').length, 1);
      expect(svc.calls.contains('playing:true'), isFalse);
      expect(svc.onAction, isNull);
      pb.dispose();
    });
  });

  group('PlatformBackgroundAudio', () {
    const channel = MethodChannel('caldero/background_audio');

    testWidgets('habla con el servicio por el canal y entrega las órdenes',
        (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final audio = PlatformBackgroundAudio();
      final got = <BackgroundAction>[];
      audio.onAction = got.add;
      await audio.start('Mi cuento', playing: true);
      await audio.setPlaying(false);
      // La notificación manda «pause» y «stop» desde Kotlin.
      for (final a in ['pause', 'stop', 'desconocida']) {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall('action', a)),
          (_) {},
        );
      }
      await audio.stop();

      expect(calls.map((c) => c.method), ['start', 'setPlaying', 'stop']);
      expect(calls.first.arguments, {'title': 'Mi cuento', 'playing': true});
      expect(calls[1].arguments, {'playing': false});
      expect(got, [BackgroundAction.pause, BackgroundAction.stop]);
    });

    testWidgets('si el teléfono rechaza el servicio, no pasa nada',
        (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final audio = PlatformBackgroundAudio();
      await audio.start('T', playing: true);
      await audio.setPlaying(true);
      await audio.stop();
    });
  });

  group('en las pantallas', () {
    void phone(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(412, 915)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('solo audio: arranca con el cuento y se quita al salir',
        (tester) async {
      phone(tester);
      final svc = _Service();
      final story = _story();
      await tester.pumpWidget(MaterialApp(
        home: AudioOnlyPage(
          story: story,
          narrator: _Voice(),
          ambience: _Music(),
          dimmer: _Screen(),
          background: svc,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(svc.calls.first, 'start:${story.title ?? story.moral.name}:true');

      // «Pausar» desde la pantalla de bloqueo
      svc.press(BackgroundAction.pause);
      await tester.pump(const Duration(milliseconds: 100));
      expect(svc.calls.last, 'playing:false');

      await close(tester);
      expect(svc.calls.last, 'stop');
    });

    testWidgets('cine: lo mismo, y al terminar la voz sigue la notificación',
        (tester) async {
      phone(tester);
      final svc = _Service();
      final art = StageArt(await tester.runAsync(
        () => loadArtLibrary(FileBundle()),
      ) as ArtLibrary);
      await tester.pumpWidget(MaterialApp(
        home: CinemaPage(
          story: _story(),
          art: art,
          setups: const [],
          narrator: _Voice(),
          ambience: _Music(),
          dimmer: _Screen(),
          background: svc,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(svc.calls.first, startsWith('start:'));
      expect(svc.calls.first, endsWith(':true'));
      await close(tester);
      expect(svc.calls.last, 'stop');
    });
  });
}
