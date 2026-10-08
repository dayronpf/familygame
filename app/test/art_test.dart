import 'dart:ui' as ui;

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/rig_renderer.dart';
import 'package:caldero_app/src/art/scene_painter.dart';
import 'package:caldero_app/src/workshop_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Dibuja con [paint] en una imagen de [w]×[h] y devuelve sus píxeles RGBA.
Future<({Uint8List rgba, int w, int h})> render(
  void Function(Canvas, Size) paint,
  int w,
  int h,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), Size(w.toDouble(), h.toDouble()));
  final image = await recorder.endRecording().toImage(w, h);
  final data = (await image.toByteData())!;
  return (rgba: data.buffer.asUint8List(), w: w, h: h);
}

List<int> px(({Uint8List rgba, int w, int h}) img, int x, int y) {
  final i = (y * img.w + x) * 4;
  return [img.rgba[i], img.rgba[i + 1], img.rgba[i + 2], img.rgba[i + 3]];
}

int luma(List<int> c) => (c[0] * 299 + c[1] * 587 + c[2] * 114) ~/ 1000;

void main() {
  late ArtLibrary art;
  setUpAll(() async {
    art = await loadArtLibrary(FileBundle());
  });

  test('carga todo el arte del pack medieval', () {
    expect(
        art.rigs.keys,
        containsAll(
            ['aldo', 'mara', 'zafiro', 'bonifacio', 'codicio', 'sombra']));
    expect(art.clips.clips.keys,
        containsAll(['idle', 'walk', 'run', 'wave', 'cheer', 'jump', 'bow']));
    expect(art.scene.layers.map((l) => l.id), ['sky', 'far', 'mid', 'near']);
  });

  group('dibujo real a píxeles', () {
    Future<({Uint8List rgba, int w, int h})> sceneImage({
      required String clip,
      double t = 0,
      bool background = true,
    }) async {
      final compiled = CompiledScene(art.scene);
      final rigs = {
        for (final e in art.rigs.entries) e.key: CompiledRig(e.value)
      };
      final actors = [
        for (final a in art.scene.actors)
          ActorInstance(
            rig: rigs[a.rig]!,
            clip: art.clips.clips[clip]!,
            x: a.x,
            y: a.y,
            scale: a.scale,
            phase: a.phase,
          ),
      ];
      final painter = ScenePainter(
        scene: compiled,
        actors: actors,
        clock: ValueNotifier(t),
        showBackground: background,
      );
      return render(painter.paint, 300, 400); // mitad de la escena (600×800)
    }

    test('el cielo es oscuro y la luna es clara', () async {
      final img = await sceneImage(clip: 'idle');
      expect(luma(px(img, 5, 5)), lessThan(40), reason: 'cielo arriba');
      final moon = px(img, 235, 75); // luna en (470,150) de la escena
      expect(luma(moon), greaterThan(200), reason: 'luna');
      expect(moon[3], 255);
    });

    test('el degradado del cielo cambia de arriba a abajo', () async {
      final img = await sceneImage(clip: 'idle');
      final top = px(img, 5, 5);
      final low = px(img, 5, 210); // aún cielo, debajo de las colinas lejanas
      expect(low[2] - top[2], greaterThan(30),
          reason: 'el azul sube hacia el horizonte');
    });

    test('los personajes se dibujan encima del fondo', () async {
      final withBg = await sceneImage(clip: 'idle');
      // Aldo está en x≈235, y≈748 (escala .8): su casco queda hacia (117, ~235)
      final bg = await sceneImage(clip: 'idle', background: false);
      final nonEmpty = [
        for (var y = 0; y < bg.h; y++)
          for (var x = 0; x < bg.w; x++)
            if (px(bg, x, y)[3] > 0) 1,
      ].length;
      expect(nonEmpty, greaterThan(3000),
          reason: 'sin fondo solo quedan personajes y sombras');
      expect(nonEmpty, lessThan(300 * 400 ~/ 3),
          reason: 'no deben llenar la imagen');
      expect(px(withBg, 5, 5)[3], 255);
    });

    test('cada clip produce una imagen distinta', () async {
      final idle = await sceneImage(clip: 'idle', t: 0.4);
      final wave = await sceneImage(clip: 'wave', t: 0.9);
      final jump = await sceneImage(clip: 'jump', t: 0.5);
      int diff(({Uint8List rgba, int w, int h}) a,
          ({Uint8List rgba, int w, int h}) b) {
        var d = 0;
        for (var i = 0; i < a.rgba.length; i += 4) {
          final delta = (a.rgba[i] - b.rgba[i]).abs() +
              (a.rgba[i + 1] - b.rgba[i + 1]).abs();
          if (delta > 40) {
            d++;
          }
        }
        return d;
      }

      expect(diff(idle, wave), greaterThan(200));
      expect(diff(idle, jump), greaterThan(200));
    });

    test('el tiempo mueve las aspas y los destellos del fondo', () async {
      final a = await sceneImage(clip: 'idle', t: 0);
      final b = await sceneImage(clip: 'idle', t: 1.1);
      var changed = 0;
      for (var i = 0; i < a.rgba.length; i += 4) {
        if ((a.rgba[i] - b.rgba[i]).abs() > 20) changed++;
      }
      expect(changed, greaterThan(150));
    });
  });

  group('taller', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: WorkshopPage(bundle: FileBundle(), freezeAt: 0)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra los clips y permite elegirlos', (tester) async {
      await open(tester);
      for (final name in ['idle', 'walk', 'run', 'wave', 'cheer', 'jump']) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.tap(find.text('wave'));
      await tester.pump();
      expect(find.byKey(const Key('scene-canvas')), findsOneWidget);
    });

    testWidgets('la prueba de carga muestra el control de personajes',
        (tester) async {
      await open(tester);
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.text('Prueba de carga (más personajes)'));
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('6 personajes'), findsOneWidget);
    });
  });
}
