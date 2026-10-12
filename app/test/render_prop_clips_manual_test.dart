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

/// Herramienta de revisión, no una prueba: dibuja un objeto animado (una cabrita, una campana…) en varios
/// instantes de una de sus animaciones, para revisar el movimiento a ojo.
///
/// Se salta si no se pide. Uso (desde `app/`):
///   PROP_OUT=/tmp/cabra PROP_ID=cabrita PROP_CLIP=goat_hop PROP_DUR=1.0 flutter test test/render_prop_clips_manual_test.dart
/// `PROP_FRAMES=8` es cuántos instantes se dibujan y `PROP_SCALE=1.8` el tamaño. Escribe `<clip>_<n>.png`.
void main() {
  final out = Platform.environment['PROP_OUT'];
  final id = Platform.environment['PROP_ID'] ?? 'cabrita';
  final clip = Platform.environment['PROP_CLIP'] ?? 'goat_walk';
  final dur = double.tryParse(Platform.environment['PROP_DUR'] ?? '') ?? 1.0;
  final frames = int.tryParse(Platform.environment['PROP_FRAMES'] ?? '') ?? 8;
  final scale =
      double.tryParse(Platform.environment['PROP_SCALE'] ?? '') ?? 1.8;

  testWidgets('dibuja una animación de un objeto', (tester) async {
    await tester.runAsync(() async {
      final pack = Pack.fromJson(
        jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
            as Map<String, Object?>,
      );
      final art = StageArt(await loadArtLibrary(FileBundle()));
      final engine = StoryEngine(pack);
      Story? story;
      for (var seed = 1; seed < 400 && story == null; seed++) {
        final s = engine.generate(StoryOptions(seed: seed, age: '2-3'));
        if (s.recipe.fragmentIds.first.startsWith('cabrita.')) story = s;
      }
      final base = Map<String, Object?>.from(story!.scenes[3].directives)
        ..['stage'] = <Object?>[]
        ..remove('focus')
        ..['props'] = [
          {'prop': id, 'clip': clip, 'x': 0.5, 'scale': scale},
        ];
      final setup = stageFor(art, story.cast, base)!;
      Directory(out!).createSync(recursive: true);
      for (var i = 0; i < frames; i++) {
        final png = await _render(setup, dur * i / frames);
        File('$out/${clip}_${i.toString().padLeft(2, '0')}.png')
            .writeAsBytesSync(png);
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
