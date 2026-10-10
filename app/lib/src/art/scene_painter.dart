import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter/animation.dart' show Curves;
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

/// Un personaje (o un objeto de la trama) en pantalla.
class ActorInstance {
  ActorInstance({
    required this.rig,
    required this.clip,
    required this.x,
    required this.y,
    required this.scale,
    this.phase = 0,
    this.shadow = true,
    this.front = false,
    this.emissive = false,
    this.walk,
    this.enterFrom = 0,
    this.t0 = 0,
  });

  final CompiledRig rig;
  final Clip clip;
  final double x, y, scale, phase;

  /// Dibuja la sombra en el suelo (los personajes sí; los objetos colgados, no).
  final bool shadow;

  /// Objeto que se dibuja por delante de los personajes.
  final bool front;

  /// Objeto que emite luz: se dibuja encima del tinte de la escena (una linterna encendida).
  final bool emissive;

  /// Entrada: el personaje llega caminando desde [enterFrom] unidades de distancia (0 = ya está).
  final Clip? walk;
  final double enterFrom;
  final double t0;

  /// La misma figura desplazada a [nx] (el modo holograma junta a los personajes hacia el centro).
  ActorInstance withX(double nx) => ActorInstance(
        rig: rig,
        clip: clip,
        x: nx,
        y: y,
        scale: scale,
        phase: phase,
        shadow: shadow,
        front: front,
        emissive: emissive,
        walk: walk,
        enterFrom: enterFrom,
        t0: t0,
      );

  ActorInstance entering({
    required double t0,
    required Clip? walk,
    required double from,
  }) =>
      ActorInstance(
        rig: rig,
        clip: clip,
        x: x,
        y: y,
        scale: scale,
        phase: phase,
        shadow: shadow,
        front: front,
        emissive: emissive,
        walk: walk,
        enterFrom: from,
        t0: t0,
      );
}

/// Dibuja la escena, sus objetos y sus personajes. [clock] da los segundos transcurridos y repinta
/// en cada cambio.
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.scene,
    required this.actors,
    required this.clock,
    this.props = const [],
    this.tint,
    this.camera = false,
    this.vignette = false,
    this.blurBackground = false,
    this.showBackground = true,
    this.view,
  }) : super(repaint: clock);

  final CompiledScene scene;
  final List<ActorInstance> actors;
  final List<ActorInstance> props;
  final ValueListenable<double> clock;
  final bool showBackground;

  /// Luz de la escena (noche, atardecer…): se multiplica sobre lo dibujado.
  final Color? tint;

  /// Desenfoca el fondo (los lugares y su luz se intuyen, pero el objeto manda): primer plano.
  final bool blurBackground;

  /// Oscurece los bordes para centrar la mirada en el objeto (primer plano).
  final bool vignette;

  /// Deriva suave de cámara (un empujón lento y un balanceo mínimo) para que la imagen no sea fija.
  final bool camera;

  /// Parte de la escena que se ve (coordenadas de la escena); `null` = toda.
  final Rect? view;

  /// Segundos que tarda un personaje en llegar caminando.
  static const double enterSeconds = 1.5;

  static final Paint _shadow = Paint()
    ..color = const Color(0x61000000); // negro al 38 %

  void _drawActor(Canvas canvas, ActorInstance a, double t) {
    var x = a.x;
    var clip = a.clip;
    var tt = t + a.phase;
    if (a.enterFrom != 0) {
      final p = ((t - a.t0) / enterSeconds).clamp(0.0, 1.0);
      if (p < 1) {
        x = a.x + a.enterFrom * (1 - Curves.easeOut.transform(p));
        clip = a.walk ?? clip;
        tt = t - a.t0;
      }
    }
    final pose = samplePose(a.rig.rig, clip, tt);
    if (a.shadow) {
      final rx = 58 * a.scale * a.rig.rig.bodyScale + 8;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, a.y + 4), width: rx * 2, height: 16),
          _shadow);
    }
    canvas.save();
    canvas.translate(x, a.y);
    canvas.scale(a.scale);
    a.rig.paint(canvas, pose);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene.scene;
    final v = view ?? Rect.fromLTWH(0, 0, s.width, s.height);
    final k = math.min(size.width / v.width, size.height / v.height);
    final t = clock.value;
    canvas.save();
    canvas.translate(
        (size.width - v.width * k) / 2, (size.height - v.height * k) / 2);
    canvas.scale(k);
    canvas.translate(-v.left, -v.top);
    canvas.clipRect(v);
    if (camera) {
      // z ≥ 1,03 y un balanceo < 1,5 % del ancho: nunca asoman los bordes.
      final z = 1.045 + 0.015 * math.sin(t * 0.35);
      canvas.translate(
          v.center.dx + math.sin(t * 0.21) * v.width * 0.011, v.center.dy);
      canvas.scale(z);
      canvas.translate(-v.center.dx, -v.center.dy);
    }

    if (showBackground) {
      if (blurBackground) {
        canvas.saveLayer(
          v.inflate(60),
          Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        );
      }
      for (final layer in scene.layers) {
        canvas.drawPicture(layer.picture);
        for (final c in layer.node.post) {
          c.draw(canvas, const {}, t, 1);
        }
      }
      if (blurBackground) canvas.restore();
    }
    for (final p in props) {
      if (!p.front && !p.emissive) _drawActor(canvas, p, t);
    }
    // De atrás hacia delante: el que pisa más abajo se dibuja encima.
    final ordered = [...actors]..sort((a, b) => a.y.compareTo(b.y));
    for (final a in ordered) {
      _drawActor(canvas, a, t);
    }
    for (final p in props) {
      if (p.front && !p.emissive) _drawActor(canvas, p, t);
    }
    final light = tint;
    if (light != null) {
      canvas.drawRect(
        v.inflate(40),
        Paint()
          ..color = light
          ..blendMode = BlendMode.modulate,
      );
    }
    for (final p in props) {
      if (p.emissive) _drawActor(canvas, p, t);
    }
    if (vignette) {
      final r = v.longestSide * 0.62;
      canvas.drawRect(
        v.inflate(40),
        Paint()
          ..shader = ui.Gradient.radial(
            v.center,
            r,
            const [Color(0x00000000), Color(0x8C000000)],
            const [0.55, 1.0],
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.scene != scene ||
      old.showBackground != showBackground ||
      old.view != view ||
      old.tint != tint ||
      old.camera != camera ||
      old.vignette != vignette ||
      old.blurBackground != blurBackground ||
      !listEquals(old.actors, actors) ||
      !listEquals(old.props, props);
}
