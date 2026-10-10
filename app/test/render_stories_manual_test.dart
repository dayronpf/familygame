import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/scene_painter.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Herramienta de revisión, no una prueba: dibuja las escenas de cuentos reales con el MISMO pintor que la
/// app y las guarda como PNG junto a su texto, para comprobar a ojo que lo que se cuenta es lo que se ve.
///
/// Se salta si no se pide. Uso (desde `app/`):
///   RENDER_OUT=/tmp/escenas RENDER_PREMISES=girasol,campana RENDER_PER=2 flutter test test/render_stories_manual_test.dart
/// Escribe `<premisa>_<n>_<escena>.png` y `<premisa>_<n>.json` (texto y directivas de cada escena).
void main() {
  final out = Platform.environment['RENDER_OUT'];
  final wanted = (Platform.environment['RENDER_PREMISES'] ?? '')
      .split(',')
      .where((e) => e.isNotEmpty)
      .toSet();
  final per = int.tryParse(Platform.environment['RENDER_PER'] ?? '') ?? 2;

  testWidgets('dibuja las escenas de cuentos reales', (tester) async {
    await tester.runAsync(() async {
      final pack = Pack.fromJson(
        jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
            as Map<String, Object?>,
      );
      final art = StageArt(await loadArtLibrary(FileBundle()));
      final engine = StoryEngine(pack);
      Directory(out!).createSync(recursive: true);
      final count = <String, int>{};
      final heroes = <String, Set<String>>{};
      for (var seed = 1; seed < 4000; seed++) {
        final story = engine.generate(StoryOptions(seed: seed));
        final id = story.scenes.first.fragmentId.split('.').first;
        if (wanted.isNotEmpty && !wanted.contains(id)) continue;
        final hero = story.recipe.cast['hero'] ?? '';
        // Un cuento por héroe distinto primero
        final seen = heroes.putIfAbsent(id, () => {});
        if ((count[id] ?? 0) >= per || seen.contains(hero) && seen.length < 2) {
          continue;
        }
        seen.add(hero);
        final n = count[id] = (count[id] ?? 0) + 1;
        final info = <Map<String, Object?>>[];
        for (var i = 0; i < story.scenes.length; i++) {
          final s = story.scenes[i];
          final setup = stageFor(art, story.cast, s.directives);
          if (setup == null) continue;
          final png = await _render(setup, 3.0);
          File('$out/${id}_${n}_${(i + 1).toString().padLeft(2, '0')}.png')
              .writeAsBytesSync(png);
          info.add({
            'n': i + 1,
            'id': s.fragmentId,
            'text': s.text,
            'directives': s.directives,
          });
        }
        File('$out/${id}_$n.json').writeAsStringSync(
          const JsonEncoder.withIndent(' ').convert({
            'title': story.title,
            'seed': seed,
            'cast': story.recipe.cast,
            'scenes': info,
          }),
        );
      }
    });
  }, skip: out == null);
}

Future<Uint8List> _render(StageSetup setup, double t) async {
  const width = 480;
  final view = setup.view;
  final height = (width * view.height / view.width).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  ScenePainter(
    scene: setup.scene,
    actors: setup.actors,
    props: setup.props,
    tint: setup.tint,
    vignette: setup.focus,
    ropes: setup.ropes,
    blurBackground: setup.focus,
    clock: ValueNotifier<double>(t),
    view: view,
  ).paint(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
