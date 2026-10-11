import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/audio/ambience.dart';
import 'package:caldero_app/src/audio_only_page.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/shared_reading_page.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/story_page.dart';
import 'package:caldero_app/src/ui/screen_dimmer.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Voz de mentira: apunta lo que «dice» y tarda un instante.
class _Voice implements Narrator {
  final said = <String>[];
  int stops = 0;
  @override
  Future<void> speak(String sentence) async {
    said.add(sentence);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
}

class _Music implements Ambience {
  int starts = 0, stops = 0;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> setLevel(double level) async {}
  @override
  Future<void> dispose() async {}
}

class _Screen implements ScreenDimmer {
  final levels = <double>[];
  int restores = 0;
  @override
  Future<void> setLevel(double level) async => levels.add(level);
  @override
  Future<void> restore() async => restores++;
}

Story _story() {
  final pack = Pack.fromJson(
    jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
        as Map<String, Object?>,
  );
  return StoryEngine(pack).generate(const StoryOptions(seed: 4, age: '4-5'));
}

void main() {
  /// Cierra la pantalla y deja pasar el tiempo para que no quede ningún temporizador pendiente.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('desde la página del cuento', () {
    Future<void> open(WidgetTester tester) async {
      phone(tester);
      final story = _story();
      await tester.pumpWidget(MaterialApp(
        home: StoryPage(
          story: story,
          onAnother: () => story,
          feedback: FeedbackService(store: MemoryFeedbackStore()),
          shelf: StoryShelf(MemoryShelfStore()),
          animate: false,
          narrator: _Voice.new,
          ambience: _Music.new,
        ),
      ));
      await tester.pump();
    }

    testWidgets('el menú ofrece «Solo audio» y «Leemos juntos»',
        (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('more-modes')));
      await tester.pumpAndSettle();
      expect(find.text('Solo audio'), findsOneWidget);
      expect(find.text('Leemos juntos'), findsOneWidget);
      await tester.tap(find.text('Leemos juntos'));
      await tester.pumpAndSettle();
      expect(find.byType(SharedReadingPage), findsOneWidget);
      await close(tester);
    });

    testWidgets('«Solo audio» deja la pantalla negra', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('more-modes')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solo audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AudioOnlyPage), findsOneWidget);
      await close(tester);
    });
  });

  group('solo audio', () {
    testWidgets('pantalla negra con el brillo al mínimo y el cuento suena',
        (tester) async {
      phone(tester);
      final voice = _Voice();
      final music = _Music();
      final screen = _Screen();
      await tester.pumpWidget(MaterialApp(
        home: AudioOnlyPage(
          story: _story(),
          narrator: voice,
          ambience: music,
          dimmer: screen,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
      expect(screen.levels, [0.0], reason: 'brillo al mínimo al entrar');
      expect(voice.said, isNotEmpty, reason: 'el cuento empieza solo');
      expect(find.byType(Image), findsNothing, reason: 'sin dibujos');
      expect(find.text('Escuchando…'), findsOneWidget);
      // al salir se devuelve el brillo
      await close(tester);
      expect(screen.restores, 1);
    });

    testWidgets('los controles se esconden solos y un toque los devuelve',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: AudioOnlyPage(
          story: _story(),
          narrator: _Voice(),
          ambience: _Music(),
          dimmer: _Screen(),
        ),
      ));
      await tester.pump();
      double opacity() => tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity;
      expect(opacity(), 1);
      await tester.pump(const Duration(seconds: 6));
      expect(opacity(), 0, reason: 'sonando, se apagan los controles');
      await tester.tap(find.byKey(const Key('audio-only-surface')));
      await tester.pump();
      expect(opacity(), 1);
      await close(tester);
    });

    testWidgets('al terminar el cuento hay un botón para volver',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AudioOnlyPage(
                  story: _story(),
                  narrator: _Voice(),
                  ambience: _Music(),
                  dimmer: _Screen(),
                ),
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('finished-back')), findsNothing);
      // la voz de mentira tarda 20 ms por frase: el cuento acaba en unos segundos
      for (var k = 0; k < 400; k++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('finished-back')).evaluate().isNotEmpty) break;
      }
      expect(find.byKey(const Key('finished-back')), findsOneWidget);
      await tester.tap(find.byKey(const Key('finished-back')));
      await tester.pumpAndSettle();
      expect(find.byType(AudioOnlyPage), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('se puede pausar y trae el temporizador de sueño',
        (tester) async {
      phone(tester);
      final voice = _Voice();
      await tester.pumpWidget(MaterialApp(
        home: AudioOnlyPage(
          story: _story(),
          narrator: voice,
          ambience: _Music(),
          dimmer: _Screen(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('sleep-timer')), findsOneWidget);
      await tester.tap(find.byTooltip('Pausa'));
      await tester.pump();
      expect(find.text('En pausa'), findsOneWidget);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pump();
      expect(find.text('Escuchando…'), findsOneWidget);
      await close(tester);
    });
  });

  group('leemos juntos', () {
    testWidgets('no suena nada solo; se avanza con los botones y deslizando',
        (tester) async {
      phone(tester);
      final voice = _Voice();
      final story = _story();
      await tester.pumpWidget(MaterialApp(
        home: SharedReadingPage(story: story, narrator: voice, animate: false),
      ));
      await tester.pump();
      expect(voice.said, isEmpty);
      expect(find.text('1 de ${story.scenes.length + 1}'), findsOneWidget);
      expect(find.byKey(const ValueKey('shared-text-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('shared-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 de ${story.scenes.length + 1}'), findsOneWidget);
      await tester.drag(
          find.byKey(const Key('shared-page-view')), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 de ${story.scenes.length + 1}'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shared-prev')));
      await tester.pumpAndSettle();
      expect(find.text('2 de ${story.scenes.length + 1}'), findsOneWidget);
      expect(voice.said, isEmpty);
      await close(tester);
    });

    testWidgets('la última página es la enseñanza y no hay «siguiente»',
        (tester) async {
      phone(tester);
      final story = _story();
      await tester.pumpWidget(MaterialApp(
        home:
            SharedReadingPage(story: story, narrator: _Voice(), animate: false),
      ));
      for (var i = 0; i < story.scenes.length; i++) {
        await tester.tap(find.byKey(const Key('shared-next')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Enseñanza'), findsOneWidget);
      expect(find.textContaining(story.moralLine), findsWidgets);
      expect(find.byKey(const Key('shared-next')), findsNothing);
      expect(find.byKey(const Key('shared-done')), findsOneWidget);
      await tester.tap(find.byKey(const Key('shared-done')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedReadingPage), findsNothing);
    });

    testWidgets('«Escuchar esta escena» lee solo esa escena', (tester) async {
      phone(tester);
      final voice = _Voice();
      final story = _story();
      await tester.pumpWidget(MaterialApp(
        home: SharedReadingPage(story: story, narrator: voice, animate: false),
      ));
      await tester.tap(find.byKey(const Key('shared-listen')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(voice.said, isNotEmpty);
      expect(voice.said.join(' '), contains(story.title!.split(' ').first));
      expect(find.text('1 de ${story.scenes.length + 1}'), findsOneWidget,
          reason: 'no pasa de página sola');
      await close(tester);
    });

    testWidgets('con turnos: la voz lee la escena 1 y le toca al adulto la 2',
        (tester) async {
      phone(tester);
      final voice = _Voice();
      final story = _story();
      await tester.pumpWidget(MaterialApp(
        home: SharedReadingPage(
            story: story, narrator: voice, animate: false, turns: true),
      ));
      await tester.pump();
      expect(find.textContaining('lee la voz'), findsNothing);
      expect(find.textContaining('Escuchamos'), findsOneWidget);
      // la voz termina la escena y pasa sola a la siguiente, que es del adulto
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('2 de ${story.scenes.length + 1}'), findsOneWidget);
      expect(find.textContaining('Te toca leer'), findsOneWidget);
      final spoken = voice.said.length;
      await tester.pump(const Duration(seconds: 3));
      expect(voice.said.length, spoken, reason: 'en su turno la voz calla');
      // pasa la página y vuelve a leer la voz
      await tester.tap(find.byKey(const Key('shared-next')));
      for (var k = 0; k < 9; k++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(voice.said.length, greaterThan(spoken),
          reason: 'en la página de la voz vuelve a leer');
      await close(tester);
    });

    testWidgets('se puede cambiar el tamaño de la letra', (tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: SharedReadingPage(
            story: _story(), narrator: _Voice(), animate: false),
      ));
      double size() {
        final t =
            tester.widget<Text>(find.byKey(const ValueKey('shared-text-0')));
        return t.textSpan!.style?.fontSize ??
            (t.textSpan! as TextSpan).children!.first.style!.fontSize!;
      }

      final before = size();
      await tester.tap(find.byKey(const Key('shared-text-bigger')));
      await tester.pump();
      expect(size(), greaterThan(before));
      await tester.tap(find.byKey(const Key('shared-text-smaller')));
      await tester.tap(find.byKey(const Key('shared-text-smaller')));
      await tester.pump();
      expect(size(), lessThan(before));
      await close(tester);
    });
  });
}
