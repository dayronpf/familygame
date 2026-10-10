import 'dart:io';
import 'dart:ui' as ui;

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/scene_painter.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

void main() {
  testWidgets('props', (tester) async {
    final art = StageArt(await loadArtLibrary(FileBundle()));
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final clock = ValueNotifier<double>(3.5);
    final place = art.library.places['rio']!;
    final v = place.view;
    ActorInstance mk(String rig, String clip, double fx, double sc, {double lift = 0}) => ActorInstance(
        rig: art.rigs[rig]!, clip: art.clip(clip)!, x: v.left + v.width * fx,
        y: place.floor - lift, scale: place.scale * sc);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: CustomPaint(
        size: const Size(640, 480),
        painter: ScenePainter(
          scene: art.sceneFor('rio')!, clock: clock, view: v,
          actors: [mk('mara', 'idle', 0.12, 1.1)],
          props: [mk('semillas', 'still', 0.3, 1.0), mk('girasol', 'sun', 0.45, 1.0), mk('piedras', 'still', 0.7, 1.0, lift: -10), mk('hierba', 'shimmer', 0.9, 1.0)],
        ),
      ),
    ));
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/claude-0/props2.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
