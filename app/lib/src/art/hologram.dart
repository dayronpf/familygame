import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'scene_painter.dart';
import 'story_stage.dart';

/// Ajustes del prisma (se guardan en el teléfono).
///
/// El prisma es una pirámide transparente invertida con la punta sobre el centro de la pantalla.
/// Cada cara refleja una de las cuatro copias de la escena. La copia ha de tener los pies hacia
/// el centro y la cabeza hacia fuera (así la figura «flota» derecha dentro del prisma) y, como cada
/// espectador la ve desde un lado, también hay que reflejarla para que izquierda y derecha no se inviertan.
class HologramLayout {
  const HologramLayout({
    this.gap = 0.3,
    this.feetInward = true,
    this.mirror = true,
  });

  /// Lado de la base del prisma, como fracción del lado corto de la pantalla.
  final double gap;

  /// Pies hacia el centro (lo correcto para un prisma con la punta hacia abajo).
  final bool feetInward;

  /// Refleja cada copia (lo correcto con una sola reflexión en la cara del prisma).
  final bool mirror;

  HologramLayout copyWith({double? gap, bool? feetInward, bool? mirror}) =>
      HologramLayout(
        gap: gap ?? this.gap,
        feetInward: feetInward ?? this.feetInward,
        mirror: mirror ?? this.mirror,
      );

  static const double minGap = 0.08;
  static const double maxGap = 0.5;

  /// Lado de cada copia para una pantalla de [size].
  double cell(Size size) {
    final m = math.min(size.width, size.height);
    return (m - m * gap) / 2;
  }

  /// Lado de la parte de escena que se ve en cada copia. Un prisma de caras a 45° solo refleja
  /// lo que cae dentro de una cuña que arranca en su base; con los pies pegados a la base, la
  /// escena ha de caber en esa cuña (≈ 1,3 veces el lado de la base).
  double scene(Size size) {
    final m = math.min(size.width, size.height);
    return math.min(cell(size), 1.3 * m * gap);
  }

  /// Cuña (90°) de la cara [i]: lo que su cara del prisma puede reflejar. Las cuatro no se pisan.
  Path wedge(int i, Size size) {
    final d = outward[i];
    final p = Offset(-d.dy, d.dx);
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width + size.height) * 2;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + (d.dx + p.dx) * r, c.dy + (d.dy + p.dy) * r)
      ..lineTo(c.dx + (d.dx - p.dx) * r, c.dy + (d.dy - p.dy) * r)
      ..close();
  }

  /// Direcciones hacia fuera de las cuatro caras: abajo, izquierda, arriba, derecha.
  static const List<Offset> outward = [
    Offset(0, 1),
    Offset(-1, 0),
    Offset(0, -1),
    Offset(1, 0),
  ];

  /// Matriz (en 2D) que coloca una copia cuadrada de lado [s] en la cara [i]; el origen de la
  /// copia es su centro. Devuelve la matriz 4×4 en columnas para [Canvas.transform].
  Float64List matrixFor(int i, Size size) {
    final s = cell(size);
    final m = math.min(size.width, size.height);
    final d = outward[i];
    // «arriba» de la imagen (cabeza) apunta hacia fuera si los pies miran al centro.
    final up = feetInward ? d : Offset(-d.dx, -d.dy);
    // «derecha» de la imagen: reflejada (un espejo) o girada (sin espejo).
    final right = mirror
        ? (feetInward ? Offset(-d.dy, d.dx) * -1 : Offset(-d.dy, d.dx))
        : (feetInward ? Offset(-d.dy, d.dx) : Offset(d.dy, -d.dx));
    final dist = m * gap / 2 + s / 2;
    final cx = size.width / 2 + d.dx * dist;
    final cy = size.height / 2 + d.dy * dist;
    // x_imagen -> right ; y_imagen (hacia abajo) -> -up
    return Float64List.fromList([
      right.dx, right.dy, 0, 0, //
      -up.dx, -up.dy, 0, 0,
      0, 0, 1, 0,
      cx, cy, 0, 1,
    ]);
  }
}

/// Cuánto se acerca el encuadre del holograma según cuántos personajes hay (1 = toda la escena).
/// Menos personajes, más cerca: así se ven grandes dentro del prisma.
double holoCrop(int actors) => actors <= 2 ? 0.55 : (actors == 3 ? 0.68 : 0.82);

/// Junta hacia el centro de la escena a los personajes y objetos de [setup] según [crop].
List<ActorInstance> holoSqueeze(
    List<ActorInstance> list, StageSetup setup, double crop) {
  final cx = setup.place.view.center.dx;
  return [for (final a in list) a.withX(cx + (a.x - cx) * crop)];
}

/// Dibuja la escena una sola vez y la repite en las cuatro caras del prisma, sobre negro.
/// Sin fondo (el negro no se refleja), con una luz suave en el suelo y destellos.
class HologramPainter extends CustomPainter {
  HologramPainter({
    required this.setup,
    required this.actors,
    required this.props,
    required this.clock,
    required this.layout,
    this.crop = 1,
  }) : super(repaint: clock);

  final StageSetup setup;
  final List<ActorInstance> actors;
  final List<ActorInstance> props;

  /// Fracción del ancho de la escena que se ve (ver [holoCrop]).
  final double crop;
  final ValueListenable<double> clock;
  final HologramLayout layout;

  /// Parte cuadrada de la escena que se ve: todo el ancho, con los pies cerca del borde inferior.
  static Rect viewFor(StageSetup setup, double crop) {
    final v = setup.place.view;
    final side = v.width * crop;
    final floor = setup.place.floor;
    return Rect.fromLTWH(
        v.center.dx - side / 2, floor + side * 0.08 - side, side, side);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF000000));
    final s = layout.cell(size);
    final q = layout.scene(size);
    if (q <= 0) return;

    final rec = ui.PictureRecorder();
    final inner = Canvas(rec);
    final view = viewFor(setup, crop);
    final t = clock.value;
    // Luz tenue en el suelo, bajo los personajes.
    final k = q / view.width;
    final floorY = (setup.place.floor - view.top) * k;
    inner.drawOval(
      Rect.fromCenter(
          center: Offset(q / 2, floorY), width: q * 0.9, height: q * 0.12),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(q / 2, floorY),
          q * 0.45,
          const [Color(0x667FE8FF), Color(0x007FE8FF)],
        ),
    );
    ScenePainter(
      scene: setup.scene,
      actors: actors,
      props: props,
      clock: clock,
      showBackground: false,
      view: view,
    ).paint(inner, Size(q, q));
    _sparkles(inner, q, t);
    final pic = rec.endRecording();

    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.clipPath(layout.wedge(i, size));
      canvas.transform(layout.matrixFor(i, size));
      // La escena va pegada al borde de la copia que mira a la base del prisma (los pies).
      canvas.translate(-q / 2, s / 2 - q);
      canvas.drawPicture(pic);
      canvas.restore();
    }
  }

  /// Motitas de luz que suben despacio (da sensación de proyección).
  static void _sparkles(Canvas c, double s, double t) {
    final p = Paint();
    for (var i = 0; i < 14; i++) {
      final seed = i * 12.9898;
      final x = (math.sin(seed) * 0.5 + 0.5) * s;
      final speed = 0.03 + (i % 5) * 0.012;
      final y =
          s - (((t * speed) + (math.cos(seed * 1.7) * 0.5 + 0.5)) % 1.0) * s;
      final a = (math.sin(t * 1.5 + i) * 0.5 + 0.5) * 0.55;
      p.color = Color.fromRGBO(190, 240, 255, a);
      c.drawCircle(Offset(x, y), s * 0.006 + (i % 3) * s * 0.002, p);
    }
  }

  @override
  bool shouldRepaint(HologramPainter old) =>
      old.setup != setup ||
      old.layout != layout ||
      old.crop != crop ||
      !listEquals(old.actors, actors) ||
      !listEquals(old.props, props);
}
