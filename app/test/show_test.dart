import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/hologram.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_app/src/audio/ambience.dart';
import 'package:caldero_app/src/cinema_page.dart';
import 'package:caldero_app/src/hologram_page.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/narration/playback.dart';
import 'package:caldero_app/src/player_support.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Voz de mentira: apunta lo que «dice» y termina enseguida (o cuando se la deja terminar).
class _FakeNarrator implements Narrator {
  final said = <String>[];
  Completer<void>? pending;
  bool manual = false;
  int stops = 0;

  @override
  Future<void> speak(String sentence) {
    said.add(sentence);
    if (!manual) return Future.value();
    return (pending = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = pending;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> dispose() async {}
}

class _FakeAmbience implements Ambience {
  int starts = 0, stops = 0;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async {}
}

void main() {
  group('frases', () {
    test('parte en frases y une las exclamaciones sueltas con la siguiente',
        () {
      final s = splitSentences(
          '¡CLANG! La campana rodó escalera abajo. «¡Fui yo!», dijo Aldo con voz clara. Nadie dijo nada.');
      expect(s.length, 2);
      expect(s.first, startsWith('¡CLANG! La campana'));
      expect(s[1], '«¡Fui yo!», dijo Aldo con voz clara. Nadie dijo nada.');
    });

    test('un texto sin puntuación es una sola frase y el vacío no da ninguna',
        () {
      expect(splitSentences('hola mundo'), ['hola mundo']);
      expect(splitSentences('   '), isEmpty);
    });

    test('el narrador por tiempo tarda según las palabras y se puede parar',
        () {
      final n = TimedNarrator(wordsPerSecond: 2, minSeconds: 1);
      expect(n.durationOf('uno'), const Duration(seconds: 1));
      expect(n.durationOf('uno dos tres cuatro cinco seis'),
          const Duration(seconds: 3));
    });
  });

  group('reproductor', () {
    PlayScene scene(String t) => PlayScene(text: t, setup: null);

    test('narra título, escenas y enseñanza en orden y termina', () async {
      final voice = _FakeNarrator();
      final pb = StoryPlayback(
        scenes: [
          scene(
              'Primera frase larga de prueba. Segunda frase larga de prueba.'),
          scene('Tercera frase larga de la segunda escena.'),
          PlayScene(
              text: 'La enseñanza de hoy: ser amable siempre.',
              setup: null,
              isMoral: true),
        ],
        narrator: voice,
        title: 'El título',
        gap: Duration.zero,
      );
      final done = Completer<void>();
      pb.addListener(() {
        if (pb.finished && !done.isCompleted) done.complete();
      });
      pb.play();
      await done.future.timeout(const Duration(seconds: 2));
      expect(voice.said.first, 'El título');
      expect(voice.said.length, 5);
      expect(voice.said.last, startsWith('La enseñanza de hoy'));
      expect(pb.scene, 2);
      expect(pb.playing, isFalse);
      pb.dispose();
    });

    test('pausar detiene la voz y continuar sigue en la misma escena',
        () async {
      final voice = _FakeNarrator()..manual = true;
      final pb = StoryPlayback(
        scenes: [
          scene('Una frase de prueba bastante larga.'),
          scene('Otra frase de prueba bastante larga.')
        ],
        narrator: voice,
        gap: Duration.zero,
      );
      pb.play();
      await Future<void>.delayed(Duration.zero);
      expect(voice.said, hasLength(1));
      await pb.pause();
      expect(pb.playing, isFalse);
      expect(voice.stops, greaterThan(0));
      await Future<void>.delayed(Duration.zero);
      expect(voice.said, hasLength(1), reason: 'pausado no avanza');
      pb.play();
      await Future<void>.delayed(Duration.zero);
      expect(pb.scene, 0);
      expect(voice.said, hasLength(2));
      pb.dispose();
    });

    test('saltar de escena corta la voz y sigue desde la nueva', () async {
      final voice = _FakeNarrator()..manual = true;
      final pb = StoryPlayback(
        scenes: [
          scene('Escena uno con varias palabras.'),
          scene('Escena dos con varias palabras.'),
          scene('Escena tres con varias palabras.')
        ],
        narrator: voice,
        gap: Duration.zero,
      );
      pb.play();
      await Future<void>.delayed(Duration.zero);
      await pb.goTo(2);
      await Future<void>.delayed(Duration.zero);
      expect(pb.scene, 2);
      expect(voice.said.last, 'Escena tres con varias palabras.');
      await pb.goTo(99);
      expect(pb.scene, 2, reason: 'no se pasa del final');
      await pb.goTo(-5);
      expect(pb.scene, 0);
      pb.dispose();
    });

    test('sin voz (narrate = false) avanza igualmente por tiempo', () async {
      final voice = _FakeNarrator();
      final pb = StoryPlayback(
          scenes: [scene('Hola.')],
          narrator: voice,
          gap: Duration.zero,
          narrate: false);
      pb.play();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(voice.said, isEmpty);
      pb.dispose();
    });
  });

  group('prisma', () {
    const size = Size(400, 700);

    /// Dónde cae, en pantalla, un punto de la copia dado en coordenadas de copia (origen: su centro).
    Offset apply(HologramLayout l, int face, Offset p) {
      final m = l.matrixFor(face, size);
      return Offset(
          m[0] * p.dx + m[4] * p.dy + m[12], m[1] * p.dx + m[5] * p.dy + m[13]);
    }

    test(
        'la escena de cada cara cabe en la pantalla y cada cuña es solo de su cara',
        () {
      const l = HologramLayout();
      final q = l.scene(size);
      final c = Offset(size.width / 2, size.height / 2);
      for (var i = 0; i < 4; i++) {
        // Esquinas de la escena de la cara i (la escena va pegada al borde de los pies).
        for (final u in [-q / 2, q / 2]) {
          for (final v in [0.0, q]) {
            final o = apply(l, i, Offset(u, l.cell(size) / 2 - v));
            expect(o.dx, inInclusiveRange(-0.5, size.width + 0.5),
                reason: 'cara $i');
            expect(o.dy, inInclusiveRange(-0.5, size.height + 0.5),
                reason: 'cara $i');
          }
        }
        // Un punto bien dentro de la cuña de i no está en ninguna otra.
        final d = HologramLayout.outward[i];
        final probe = c + d * (size.shortestSide * 0.3);
        for (var j = 0; j < 4; j++) {
          expect(l.wedge(j, size).contains(probe), j == i, reason: '$i/$j');
        }
      }
    });

    test(
        'con los pies hacia dentro, la cabeza apunta fuera del centro en las cuatro caras',
        () {
      final l = const HologramLayout();
      final c = Offset(size.width / 2, size.height / 2);
      for (var i = 0; i < 4; i++) {
        final feet = apply(l, i, const Offset(0, 40));
        final head = apply(l, i, const Offset(0, -40));
        expect((feet - c).distance, lessThan((head - c).distance),
            reason: 'cara $i');
      }
    });

    test('con los pies hacia fuera ocurre lo contrario', () {
      final l = const HologramLayout(feetInward: false);
      final c = Offset(size.width / 2, size.height / 2);
      for (var i = 0; i < 4; i++) {
        final feet = apply(l, i, const Offset(0, 40));
        final head = apply(l, i, const Offset(0, -40));
        expect((feet - c).distance, greaterThan((head - c).distance));
      }
    });

    test(
        'con espejo, la derecha de la copia es la derecha de quien la mira desde su lado',
        () {
      final l = const HologramLayout();
      // Espectador abajo (cara 0): su derecha es la derecha de la pantalla (+x).
      final r0 = apply(l, 0, const Offset(10, 0)) - apply(l, 0, Offset.zero);
      expect(r0.dx, greaterThan(0));
      // Espectador arriba (cara 2): ve la pantalla del revés, su derecha es -x.
      final r2 = apply(l, 2, const Offset(10, 0)) - apply(l, 2, Offset.zero);
      expect(r2.dx, lessThan(0));
      // Espectador a la izquierda (cara 1): mira hacia +x; su derecha apunta hacia abajo (+y).
      final r1 = apply(l, 1, const Offset(10, 0)) - apply(l, 1, Offset.zero);
      expect(r1.dy, greaterThan(0));
      // Espectador a la derecha (cara 3): su derecha apunta hacia arriba (-y).
      final r3 = apply(l, 3, const Offset(10, 0)) - apply(l, 3, Offset.zero);
      expect(r3.dy, lessThan(0));
    });

    test(
        'sin espejo es un giro puro (determinante positivo) y con espejo es un reflejo',
        () {
      for (var i = 0; i < 4; i++) {
        double det(HologramLayout l) {
          final m = l.matrixFor(i, size);
          return m[0] * m[5] - m[1] * m[4];
        }

        expect(det(const HologramLayout(mirror: false)), closeTo(1, 1e-9));
        expect(det(const HologramLayout()), closeTo(-1, 1e-9));
      }
    });

    test('un prisma más grande deja copias más pequeñas', () {
      expect(const HologramLayout(gap: 0.4).cell(size),
          lessThan(const HologramLayout(gap: 0.1).cell(size)));
      expect(math.min(size.width, size.height), 400);
    });
  });

  group('pantallas', () {
    late StageArt art;
    late Story story;
    late List<StageSetup?> setups;

    setUpAll(() async {
      art = StageArt(await loadArtLibrary(FileBundle()));
      final pack = Pack.fromJson(
        jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
            as Map<String, Object?>,
      );
      story = StoryEngine(pack)
          .generate(const StoryOptions(seed: 5, valueId: 'valentia'));
      setups = [
        for (final s in story.scenes) stageFor(art, story.cast, s.directives)
      ];
    });

    test(
        'las escenas a reproducir terminan con la enseñanza y heredan el dibujo',
        () {
      final scenes = playScenes(story, setups);
      expect(scenes.length, story.scenes.length + 1);
      expect(scenes.last.isMoral, isTrue);
      expect(scenes.last.text, contains(story.moral.text));
      expect(scenes.every((s) => s.setup != null), isTrue);
    });

    testWidgets('el holograma no muestra texto del cuento y avanza con la voz',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final voice = _FakeNarrator();
      final bg = _FakeAmbience();
      await tester.pumpWidget(MaterialApp(
        home: HologramPage(
            story: story,
            art: art,
            setups: setups,
            narrator: voice,
            ambience: bg),
      ));
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(bg.starts, 1);
      // Ninguna palabra del cuento aparece escrita en pantalla.
      for (final s in story.scenes) {
        expect(find.textContaining(s.text.substring(0, 20)), findsNothing);
      }
      expect(find.byType(Text), findsNothing,
          reason: 'el holograma es solo dibujo; los controles son iconos');
      // La voz va diciendo frases y el cuento llega al final.
      for (var i = 0; i < 400 && voice.said.length < 20; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(voice.said.first, story.title);
      expect(voice.said.length, greaterThan(15));
      // Cierra sin errores.
      await tester.pumpWidget(const SizedBox());
      expect(bg.stops, greaterThan(0));
    });

    testWidgets(
        'el cine muestra el subtítulo con la frase que suena y los controles',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final voice = _FakeNarrator()..manual = true;
      await tester.pumpWidget(MaterialApp(
        home: CinemaPage(
          story: story,
          art: art,
          setups: setups,
          narrator: voice,
          ambience: _FakeAmbience(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byTooltip('Ver en holograma'), findsOneWidget);
      expect(find.byTooltip('Pausa'), findsOneWidget);
      expect(voice.said.first, story.title);
      // Se acaba el título: pasa a la primera escena y se ve su texto.
      voice.pending!.complete();
      await tester.pump(const Duration(seconds: 1));
      final first = story.scenes.first.text.split(' ').take(3).join(' ');
      expect(find.textContaining(first, findRichText: true), findsWidgets);
      await tester.tap(find.byTooltip('Pausa'));
      await tester.pump();
      expect(find.byTooltip('Reproducir'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
