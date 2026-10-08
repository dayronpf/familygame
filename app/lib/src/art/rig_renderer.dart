import 'dart:ui' as ui;

import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter/painting.dart';

ui.Path _toPath(List<PathCmd> cmds) {
  final p = ui.Path();
  for (final c in cmds) {
    switch (c) {
      case MoveTo(:final x, :final y):
        p.moveTo(x, y);
      case LineTo(:final x, :final y):
        p.lineTo(x, y);
      case QuadTo(:final cx, :final cy, :final x, :final y):
        p.quadraticBezierTo(cx, cy, x, y);
      case CubicTo(
          :final c1x,
          :final c1y,
          :final c2x,
          :final c2y,
          :final x,
          :final y
        ):
        p.cubicTo(c1x, c1y, c2x, c2y, x, y);
      case ArcTo(
          :final rx,
          :final ry,
          :final rotation,
          :final largeArc,
          :final sweep,
          :final x,
          :final y
        ):
        p.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
      case ClosePath():
        p.close();
    }
  }
  return p;
}

Color _color(Argb argb) => Color(argb);

/// Forma lista para dibujar: ruta y pinceles creados una sola vez.
class CompiledShape {
  CompiledShape._(this.path, this.fill, this.fillColor, this.stroke,
      this.strokeColor, this.opacity);

  final ui.Path path;
  final Paint? fill;
  final Color? fillColor; // null si el relleno es un degradado
  final Paint? stroke;
  final Color? strokeColor;
  final double opacity;

  void draw(Canvas canvas, double groupOpacity) {
    final a = opacity * groupOpacity;
    if (a <= 0) return;
    final f = fill;
    if (f != null) {
      f.color = (fillColor ?? const Color(0xFFFFFFFF))
          .withValues(alpha: (fillColor?.a ?? 1) * a);
      canvas.drawPath(path, f);
    }
    final s = stroke;
    if (s != null) {
      s.color = strokeColor!.withValues(alpha: strokeColor!.a * a);
      canvas.drawPath(path, s);
    }
  }
}

/// Resuelve `$token`, `#hex` o `auto` a un color.
Argb? _resolve(String? v, Map<String, String> palette) {
  if (v == null || v == 'auto' || v.startsWith('@')) return null;
  if (v.startsWith(r'$')) {
    final hex = palette[v.substring(1)];
    if (hex == null) {
      throw ArtFormatException('el color $v no está en la paleta');
    }
    return parseHexColor(hex);
  }
  return parseHexColor(v);
}

Shader _gradient(SceneGradient g, Rect b) {
  final colors = [
    for (final s in g.stops)
      Color(parseHexColor(s.color)).withValues(alpha: s.opacity)
  ];
  final stops = [for (final s in g.stops) s.offset];
  if (g.linear) {
    return ui.Gradient.linear(
      Offset(b.left + g.from[0] * b.width, b.top + g.from[1] * b.height),
      Offset(b.left + g.to[0] * b.width, b.top + g.to[1] * b.height),
      colors,
      stops,
    );
  }
  return ui.Gradient.radial(b.center, b.width / 2, colors, stops);
}

CompiledShape compileShape(
  RigShape s,
  Map<String, String> palette,
  Map<String, SceneGradient> gradients,
) {
  final path = _toPath(s.commands);
  Paint? fill;
  Color? fillColor;
  final f = s.fill;
  if (f != null) {
    fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    if (f.startsWith('@')) {
      final g = gradients[f.substring(1)] ??
          (throw ArtFormatException('degradado desconocido: $f'));
      fill.shader = _gradient(g, path.getBounds());
    } else {
      fillColor = _color(_resolve(f, palette)!);
    }
  }
  Paint? stroke;
  Color? strokeColor;
  if (s.strokeWidth > 0 && s.stroke != null) {
    Argb? argb;
    if (s.stroke == 'auto') {
      final solid = _resolve(f, palette);
      if (solid != null) argb = autoStroke(solid);
    } else {
      argb = _resolve(s.stroke, palette);
    }
    if (argb != null) {
      strokeColor = _color(argb);
      stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
    }
  }
  return CompiledShape._(path, fill, fillColor, stroke, strokeColor, s.opacity);
}

/// Hueso listo para dibujar.
class CompiledNode {
  CompiledNode._(this.node, this.pre, this.shapes, this.post)
      : keyDx = '${node.id}.dx',
        keyDy = '${node.id}.dy',
        keySx = '${node.id}.sx',
        keySy = '${node.id}.sy';

  factory CompiledNode.compile(
    RigNode n,
    Map<String, String> palette,
    Map<String, SceneGradient> gradients,
  ) =>
      CompiledNode._(
        n,
        [for (final c in n.pre) CompiledNode.compile(c, palette, gradients)],
        [for (final s in n.shapes) compileShape(s, palette, gradients)],
        [for (final c in n.post) CompiledNode.compile(c, palette, gradients)],
      );

  final RigNode node;
  final List<CompiledNode> pre, post;
  final List<CompiledShape> shapes;
  final String keyDx, keyDy, keySx, keySy;

  void drawShapes(Canvas canvas, double go) {
    for (final s in shapes) {
      s.draw(canvas, go);
    }
  }

  /// Dibuja el hueso con la [pose] del clip y las animaciones ambientales en el tiempo [t].
  void draw(Canvas canvas, Pose pose, double t, double groupOpacity) {
    final n = node;
    var angle = n.restRotation + (pose[n.id] ?? 0);
    var go = groupOpacity;
    for (final a in n.anims) {
      final v = sampleAmbient(a, t);
      if (a.prop == 'rotate') {
        angle += v;
      } else {
        go *= v;
      }
    }
    final dx = pose[keyDx] ?? 0;
    final dy = pose[keyDy] ?? 0;
    final sx = pose[keySx] ?? 1;
    final sy = pose[keySy] ?? 1;
    final transformed = dx != 0 || dy != 0 || angle != 0 || sx != 1 || sy != 1;
    if (transformed) {
      canvas.save();
      if (dx != 0 || dy != 0) canvas.translate(dx, dy);
      if (angle != 0) {
        canvas.translate(n.pivotX, n.pivotY);
        canvas.rotate(angle * 0.017453292519943295);
        canvas.translate(-n.pivotX, -n.pivotY);
      }
      if (sx != 1 || sy != 1) {
        canvas.translate(n.pivotX, n.pivotY);
        canvas.scale(sx, sy);
        canvas.translate(-n.pivotX, -n.pivotY);
      }
    }
    for (final c in pre) {
      c.draw(canvas, pose, t, go);
    }
    drawShapes(canvas, go);
    for (final c in post) {
      c.draw(canvas, pose, t, go);
    }
    if (transformed) canvas.restore();
  }
}

/// Personaje compilado.
class CompiledRig {
  CompiledRig(this.rig)
      : root = CompiledNode.compile(rig.root, rig.palette, const {});

  final Rig rig;
  final CompiledNode root;

  static const Pose _noPose = {};

  void paint(Canvas canvas, Pose pose) {
    final sc = rig.bodyScale;
    if (sc != 1) {
      canvas.save();
      canvas.scale(sc, 1);
    }
    root.draw(canvas, pose, 0, 1);
    if (sc != 1) canvas.restore();
  }

  // Para pruebas y el modo sin animación.
  void paintRest(Canvas canvas) => paint(canvas, _noPose);
}
