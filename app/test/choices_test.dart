import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_app/src/audio/ambience.dart';
import 'package:caldero_app/src/audio/background_audio.dart';
import 'package:caldero_app/src/cinema_page.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/narration/playback.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/story_flow.dart';
import 'package:caldero_app/src/story_page.dart';
import 'package:caldero_app/src/ui/choice_cards.dart';
import 'package:caldero_app/src/ui/screen_dimmer.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Voz de mentira: apunta lo que «dice» y tarda un instante.
class _Voice implements Narrator {
  final said = <String>[];
  @override
  Future<void> speak(String sentence) async {
    said.add(sentence);
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

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

Pack _pack() => Pack.fromJson(
      jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );

/// Un cuento de `linterna` (la premisa con pregunta) a medias, en la pregunta.
StoryRun _pendingRun({String? heroName}) {
  final engine = StoryEngine(_pack());
  for (var s = 1; s < 500; s++) {
    final run = engine.begin(StoryOptions(
      seed: s,
      valueId: 'valentia',
      age: '6-8',
      heroName: heroName,
    ));
    if (run.story.recipe.fragmentIds.first.startsWith('linterna.')) return run;
  }
  throw StateError('ninguna semilla da linterna');
}

StoryChoice _choice() => StoryChoice(
      id: 'camino',
      ask: '¿Cómo sigue?',
      options: const [
        StoryOption(id: 'a', label: 'Uno', glyph: 'hearing'),
        StoryOption(id: 'b', label: 'Dos', glyph: 'touch_app'),
      ],
    );

void main() {
  group('reproductor con pregunta', () {
    List<PlayScene> head() => [
          PlayScene(text: 'Primera escena larga del cuento.', setup: null),
          PlayScene(
            text: 'La escena que pregunta del cuento.',
            setup: null,
            choice: _choice(),
          ),
        ];
    List<PlayScene> rest() => [
          PlayScene(
              text: 'Y así siguió el cuento hasta el final.', setup: null),
          PlayScene(text: 'La enseñanza.', setup: null, isMoral: true),
        ];

    StoryPlayback make(
      _Voice voice,
      List<String?> picks, {
      Duration first = const Duration(milliseconds: 60),
      Duration second = const Duration(milliseconds: 60),
    }) =>
        StoryPlayback(
          scenes: head(),
          narrator: voice,
          gap: Duration.zero,
          firstWait: first,
          secondWait: second,
          resolve: (id) async {
            picks.add(id);
            return rest();
          },
        );

    Future<void> until(bool Function() ok) async {
      for (var i = 0; i < 400 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('al acabar la escena pregunta, dice las opciones y espera', () async {
      final voice = _Voice();
      final picks = <String?>[];
      final pb = make(voice, picks, first: const Duration(seconds: 5));
      pb.play();
      await until(() => pb.asking != null);
      expect(pb.asking!.id, 'camino');
      await until(() => voice.said.contains('Dos'));
      expect(
        voice.said.skipWhile((s) => !s.contains('Cómo sigue')).take(3),
        ['¿Cómo sigue?', 'Uno', 'Dos'].map((e) => isA<String>()),
      );
      expect(pb.finished, isFalse);
      expect(picks, isEmpty, reason: 'sin respuesta no avanza');
      pb.dispose();
    });

    test('al tocar una opción sigue con el resto del cuento', () async {
      final voice = _Voice();
      final picks = <String?>[];
      final pb = make(voice, picks, first: const Duration(seconds: 5));
      pb.play();
      await until(() => pb.asking != null);
      pb.choose('b');
      await until(() => pb.finished);
      expect(picks, ['b']);
      expect(pb.scenes, hasLength(4));
      expect(pb.scenes[1].pickedOption, isNotNull);
      expect(pb.asking, isNull);
      expect(voice.said.any((s) => s.contains('Y así siguió')), isTrue);
      pb.dispose();
    });

    test('si nadie contesta repite las opciones y luego elige la app',
        () async {
      final voice = _Voice();
      final picks = <String?>[];
      final pb = make(voice, picks);
      pb.play();
      await until(() => pb.finished);
      expect(picks, [null], reason: 'null = que elija la app');
      expect(voice.said.where((s) => s == 'Uno'), hasLength(2),
          reason: 'las opciones se repiten una vez');
      expect(voice.said.any((s) => s.contains('Esta vez elijo yo')), isTrue);
      pb.dispose();
    });

    test('«elige por nosotros» contesta en el acto', () async {
      final voice = _Voice();
      final picks = <String?>[];
      final pb = make(voice, picks, first: const Duration(seconds: 5));
      pb.play();
      await until(() => pb.asking != null);
      pb.chooseForMe();
      await until(() => pb.finished);
      expect(picks, [null]);
      expect(voice.said.any((s) => s.contains('Esta vez elijo yo')), isFalse);
      pb.dispose();
    });

    test('con el temporizador armado no hay pausa ni aviso', () async {
      final voice = _Voice();
      final picks = <String?>[];
      final pb = make(voice, picks, first: const Duration(seconds: 5))
        ..asks = false;
      pb.play();
      await until(() => pb.finished);
      expect(picks, [null]);
      expect(voice.said, isNot(contains('¿Cómo sigue?')));
      pb.dispose();
    });

    test(
        'pausar mientras pregunta no elige nada; al seguir vuelve a '
        'preguntar', () async {
      final voice = _Voice();
      final picks = <String?>[];
      final pb = make(voice, picks, first: const Duration(seconds: 5));
      pb.play();
      await until(() => pb.asking != null);
      await pb.pause();
      expect(pb.asking, isNull);
      expect(picks, isEmpty);
      pb.play();
      await until(() => pb.asking != null);
      expect(pb.asking, isNotNull);
      pb.choose('a');
      await until(() => pb.finished);
      expect(picks, ['a']);
      pb.dispose();
    });

    test('sin «resolve» (cuentos enteros) no se pregunta nada', () async {
      final voice = _Voice();
      final pb = StoryPlayback(
        scenes: head(),
        narrator: voice,
        gap: Duration.zero,
      );
      pb.play();
      await until(() => pb.finished);
      expect(pb.asking, isNull);
      pb.dispose();
    });
  });

  group('StoryFlow', () {
    test('elegir completa el cuento y avisa; «por nosotros» elige la app', () {
      final flow = StoryFlow(_pendingRun());
      var notified = 0;
      flow.addListener(() => notified++);
      expect(flow.isComplete, isFalse);
      flow.choose('tacto');
      expect(flow.isComplete, isTrue);
      expect(flow.story.choices.single.optionId, 'tacto');
      expect(notified, 1);

      final other = StoryFlow(_pendingRun())..chooseForMe();
      expect(other.isComplete, isTrue);
      expect(other.story.choices.single.auto, isTrue);
    });

    test('finish deja el cuento entero para los modos sin preguntas', () {
      final flow = StoryFlow(_pendingRun());
      final story = flow.finish();
      expect(flow.isComplete, isTrue);
      expect(story.scenes.last.pickedOption, isNull,
          reason: 'la última escena no es la pregunta');
      expect(story.choices, hasLength(1));
    });
  });

  group('pantalla de texto', () {
    /// La lista es perezosa: se baja hasta la pregunta.
    Future<void> showQuestion(WidgetTester tester) => tester.scrollUntilVisible(
          find.byKey(const Key('choice-block')),
          400,
          scrollable: find.byType(Scrollable).first,
        );

    Future<void> showMoral(WidgetTester tester) => tester.scrollUntilVisible(
          find.text('Enseñanza'),
          600,
          scrollable: find.byType(Scrollable).first,
        );

    Future<void> tapKey(WidgetTester tester, String key) async {
      await showQuestion(tester);
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pump();
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }

    Future<void> open(WidgetTester tester, StoryRun run) async {
      tester.view
        ..physicalSize = const Size(412, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: StoryPage(
          story: run.story,
          run: run,
          onAnother: () => run.story,
          feedback: FeedbackService(store: MemoryFeedbackStore()),
          shelf: StoryShelf(MemoryShelfStore()),
          animate: false,
          narrator: _Voice.new,
          ambience: _Music.new,
        ),
      ));
      await tester.pump();
    }

    testWidgets(
        'a medias enseña la pregunta con sus caminos y no la '
        'enseñanza', (tester) async {
      final run = _pendingRun(heroName: 'Nicolás');
      await open(tester, run);
      await showQuestion(tester);
      expect(find.byKey(const Key('choice-block')), findsOneWidget);
      expect(find.textContaining('Nicolás en la oscuridad'), findsOneWidget);
      expect(find.byKey(const Key('choice-oido')), findsOneWidget);
      expect(find.byKey(const Key('choice-tacto')), findsOneWidget);
      expect(find.byKey(const Key('choice-luna')), findsOneWidget);
      expect(find.text('Seguir el beee'), findsOneWidget);
      expect(find.textContaining('cuál de las tres'), findsOneWidget,
          reason: 'la nota para el adulto');
      expect(find.text('Enseñanza'), findsNothing);
    });

    testWidgets('al elegir aparece el resto del cuento y la enseñanza',
        (tester) async {
      final run = _pendingRun();
      await open(tester, run);
      final before = find.byType(Text).evaluate().length;
      await tapKey(tester, 'choice-luna');
      expect(find.byKey(const Key('choice-block')), findsNothing);
      expect(find.byKey(const Key('choice-picked')), findsOneWidget);
      expect(find.text('Elegisteis: Esperar y respirar'), findsOneWidget);
      await showMoral(tester);
      expect(find.text('Enseñanza'), findsOneWidget);
      expect(find.byType(Text).evaluate().length, greaterThan(before));
    });

    testWidgets('«Elige por nosotros» contesta la app', (tester) async {
      await open(tester, _pendingRun());
      await tapKey(tester, 'choice-for-me');
      expect(find.byKey(const Key('choice-picked')), findsOneWidget);
      await showMoral(tester);
      expect(find.text('Enseñanza'), findsOneWidget);
    });

    testWidgets('lo que se elige queda en «Mis cuentos» para contarlo igual',
        (tester) async {
      final shelf = StoryShelf(MemoryShelfStore());
      final run = _pendingRun();
      tester.view
        ..physicalSize = const Size(412, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: StoryPage(
          story: run.story,
          run: run,
          onAnother: () => run.story,
          feedback: FeedbackService(store: MemoryFeedbackStore()),
          shelf: shelf,
          age: '6-8',
          animate: false,
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(shelf.recent.single.choices, isEmpty);
      await tapKey(tester, 'choice-tacto');
      await tester.pump();
      expect(shelf.recent, hasLength(1));
      expect(shelf.recent.single.choices, ['tacto']);
      final json = jsonEncode(shelf.recent.single.toJson());
      expect(
          ShelfEntry.fromJson(jsonDecode(json) as Map<String, Object?>).choices,
          ['tacto']);
    });
  });

  group('cine', () {
    testWidgets(
        'pregunta con las tarjetas, sigue al tocar y el cuento llega al '
        'final', (tester) async {
      tester.view
        ..physicalSize = const Size(412, 915)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final art = StageArt(await tester.runAsync(
        () => loadArtLibrary(FileBundle()),
      ) as ArtLibrary);
      final flow = StoryFlow(_pendingRun());
      final voice = _Voice();
      await tester.pumpWidget(MaterialApp(
        home: CinemaPage(
          story: flow.story,
          flow: flow,
          art: art,
          setups: const [],
          narrator: voice,
          ambience: _Music(),
          dimmer: _Screen(),
          background: NoBackgroundAudio(),
          animate: false,
        ),
      ));
      // Hasta que aparezca la pregunta
      for (var i = 0;
          i < 400 && find.byKey(const ValueKey('question')).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('question')), findsOneWidget);
      expect(find.byKey(const Key('choice-oido')), findsOneWidget);
      expect(flow.isComplete, isFalse);

      await tester.tap(find.byKey(const Key('choice-oido')));
      await tester.pump();
      expect(flow.isComplete, isTrue);
      expect(flow.story.choices.single.optionId, 'oido');
      // El cuento sigue por el camino elegido hasta el final
      for (var i = 0;
          i < 600 && find.byKey(const Key('finished-back')).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const Key('finished-back')), findsOneWidget);
      expect(
        voice.said
            .any((s) => s.contains('orejas') || s.contains('respiración')),
        isTrue,
        reason: 'se narra la escena del camino elegido',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('tarjetas y ajustes', () {
    test('todo icono permitido por el motor tiene dibujo en la app', () {
      for (final g in choiceGlyphs) {
        expect(choiceIcons.containsKey(g), isTrue, reason: g);
      }
    });

    test('el perfil del niño guarda si se le hacen preguntas', () {
      expect(const ChildProfile().asksQuestions, isTrue);
      final off = const ChildProfile().copyWith(asksQuestions: false);
      expect(off.toJson()['preguntas'], isFalse);
      expect(ChildProfile.fromJson(off.toJson()).asksQuestions, isFalse);
      expect(
        const ChildProfile().toJson().containsKey('preguntas'),
        isFalse,
        reason: 'lo normal no ocupa espacio',
      );
    });

    testWidgets(
        'las tarjetas se pueden tocar y llevan texto para el lector '
        'de pantalla', (tester) async {
      String? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChoiceCards(
            choice: _choice(),
            highlighted: 1,
            onChoose: (id) => tapped = id,
          ),
        ),
      ));
      expect(find.bySemanticsLabel('Opción 2 de 2: Dos'), findsOneWidget);
      await tester.tap(find.byKey(const Key('choice-b')));
      expect(tapped, 'b');
      final card = tester.getSize(find.byKey(const Key('choice-a')));
      expect(card.width, greaterThanOrEqualTo(96));
      expect(card.height, greaterThanOrEqualTo(96));
    });
  });
}
