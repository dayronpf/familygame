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

/// Herramienta de revisión, no una prueba: dibuja cada animación de los personajes (cuerpo entero y primer plano
/// de la cara) en su momento más expresivo, para revisar poses y expresiones a ojo.
///
/// Se salta si no se pide. Uso (desde `app/`):
///   POSES_OUT=/tmp/poses POSES_RIGS=aldo,mara,rosa flutter test test/render_poses_manual_test.dart
/// `POSES_CLIPS=cheer,sad` limita las animaciones y `POSES_T=0.4` es la fracción de la duración que se dibuja.
/// Escribe `<animación>_<personaje>_cuerpo.png` y `_cara.png`.
void main() {
  final out = Platform.environment['POSES_OUT'];
  final rigs = (Platform.environment['POSES_RIGS'] ?? 'aldo,mara,rosa,zafiro')
      .split(',')
      .where((e) => e.isNotEmpty)
      .toList();
  final clipsWanted = (Platform.environment['POSES_CLIPS'] ?? '')
      .split(',')
      .where((e) => e.isNotEmpty)
      .toList();
  final frac = double.tryParse(Platform.environment['POSES_T'] ?? '') ?? 0.4;

  testWidgets('dibuja poses y expresiones', (tester) async {
    await tester.runAsync(() async {
      final pack = Pack.fromJson(
        jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
            as Map<String, Object?>,
      );
      final art = StageArt(await loadArtLibrary(FileBundle()));
      final place = pack.places.firstWhere((p) => p.id == 'aldea');
      Directory(out!).createSync(recursive: true);
      final humanoid = jsonDecode(
        File('../art/clips/humanoid.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final names = clipsWanted.isNotEmpty
          ? clipsWanted
          : (humanoid['clips']! as Map<String, Object?>).keys.toList();
      for (final name in names) {
        for (final rig in rigs) {
          final setup = stageFor(
            art,
            {'plaza': place},
            {
              'bg': 'plaza',
              'time': 'dia',
              'stage': [
                {'rig': rig, 'clip': name, 'x': 0.5, 'scale': 1.7},
              ],
            },
          );
          if (setup == null || setup.actors.isEmpty) continue;
          final a = setup.actors.first;
          final t = a.clip.dur * frac;
          File('$out/${name}_${rig}_cuerpo.png').writeAsBytesSync(await _render(
            setup,
            t,
            Rect.fromCenter(
              center: Offset(a.x, a.y - 120 * a.scale),
              width: 330 * a.scale,
              height: 330 * a.scale * 0.75,
            ),
            300,
          ));
          final c = Offset(a.x, a.y - 190 * a.scale);
          final w = 150 * a.scale;
          final face = Rect.fromCenter(center: c, width: w, height: w);
          File('$out/${name}_${rig}_cara.png')
              .writeAsBytesSync(await _render(setup, t, face, 240));
        }
      }
    });
  }, skip: out == null);
}

Future<Uint8List> _render(
  StageSetup setup,
  double t,
  Rect view,
  int width,
) async {
  final height = (width * view.height / view.width).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  ScenePainter(
    scene: setup.scene,
    actors: setup.actors,
    props: setup.props,
    tint: setup.tint,
    vignette: false,
    ropes: setup.ropes,
    blurBackground: false,
    clock: ValueNotifier<double>(t),
    view: view,
  ).paint(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
