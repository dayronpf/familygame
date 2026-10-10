import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'rig_renderer.dart';

/// Capa de fondo compilada. Sus formas estáticas se graban una sola vez como imagen reproducible.
class CompiledLayer {
  CompiledLayer(RigNode layer, Map<String, SceneGradient> gradients)
      : node = CompiledNode.compile(layer, const {}, gradients) {
    final recorder = ui.PictureRecorder();
    node.drawShapes(Canvas(recorder), 1);
    picture = recorder.endRecording();
  }

  final CompiledNode node;
  late final ui.Picture picture;
}

/// Escena compilada: capas y degradados listos.
class CompiledScene {
  CompiledScene(this.scene)
      : layers = [
          for (final l in scene.layers) CompiledLayer(l, scene.gradients)
        ];

  final Scene scene;
  final List<CompiledLayer> layers;
}

/// Un personaje en pantalla.
class ActorInstance {
  ActorInstance({
    required this.rig,
    required this.clip,
    required this.x,
    required this.y,
    required this.scale,
    this.phase = 0,
  });

  final CompiledRig rig;
  final Clip clip;
  final double x, y, scale, phase;
}

/// Dibuja la escena y sus personajes. [clock] da los segundos transcurridos y repinta en cada cambio.
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.scene,
    required this.actors,
    required this.clock,
    this.showBackground = true,
    this.view,
  }) : super(repaint: clock);

  final CompiledScene scene;
  final List<ActorInstance> actors;
  final ValueListenable<double> clock;
  final bool showBackground;

  /// Parte de la escena que se ve (coordenadas de la escena); `null` = toda.
  final Rect? view;

  static final Paint _shadow = Paint()
    ..color = const Color(0x61000000); // negro al 38 %

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene.scene;
    final v = view ?? Rect.fromLTWH(0, 0, s.width, s.height);
    final k = math.min(size.width / v.width, size.height / v.height);
    canvas.save();
    canvas.translate(
        (size.width - v.width * k) / 2, (size.height - v.height * k) / 2);
    canvas.scale(k);
    canvas.translate(-v.left, -v.top);
    canvas.clipRect(v);
    final t = clock.value;

    if (showBackground) {
      for (final layer in scene.layers) {
        canvas.drawPicture(layer.picture);
        for (final c in layer.node.post) {
          c.draw(canvas, const {}, t, 1);
        }
      }
    }
    for (final a in actors) {
      final pose = samplePose(a.rig.rig, a.clip, t + a.phase);
      final rx = 58 * a.scale * a.rig.rig.bodyScale + 8;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(a.x, a.y + 4), width: rx * 2, height: 16),
          _shadow);
      canvas.save();
      canvas.translate(a.x, a.y);
      canvas.scale(a.scale);
      a.rig.paint(canvas, pose);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.scene != scene ||
      old.showBackground != showBackground ||
      old.view != view ||
      !listEquals(old.actors, actors);
}
