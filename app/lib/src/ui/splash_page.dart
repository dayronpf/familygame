import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../feedback/rating_event.dart';
import 'night_background.dart';
import 'palette.dart';

/// Pantalla de bienvenida: una noche de cuento, la luna sale, el caldero hierve y de él suben estrellitas;
/// aparece el nombre y, abajo y muy pequeña, la versión. Se queda al menos [minimum] y hasta que [ready] termine
/// (así el inicio ya está cargado cuando cae el splash).
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.onFinished,
    this.ready,
    this.version = appVersion,
    this.minimum = const Duration(milliseconds: 3000),
  });

  final VoidCallback onFinished;

  /// Lo que hay que cargar mientras se ve el splash.
  final Future<void>? ready;
  final String version;
  final Duration minimum;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: widget.minimum,
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loop.repeat();
    final ready = widget.ready ?? Future<void>.value();
    // Se espera por el estado y no por el futuro de `forward()`: con «reducir movimiento» la animación se salta
    // poniéndole el valor final, y ese futuro quedaría cancelado para siempre (el splash no caería nunca).
    final introDone = Completer<void>();
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && !introDone.isCompleted) {
        introDone.complete();
      }
    });
    _intro.forward();
    Future.wait<void>([
      introDone.future,
      ready.catchError((_) {}),
    ]).then((_) {
      if (mounted && !_done) {
        _done = true;
        widget.onFinished();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop.stop();
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Un valor 0→1 dentro de la franja [a, b] de la animación de entrada.
  double _span(double a, double b) =>
      Curves.easeOutCubic.transform(((_intro.value - a) / (b - a)).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: NightBackground(
        stars: 70,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _loop]),
            builder: (context, _) {
              final title = _span(0.30, 0.62);
              final tagline = _span(0.55, 0.85);
              final version = _span(0.75, 1.0);
              return Column(
                children: [
                  const Spacer(flex: 2),
                  Semantics(
                    label: 'Un caldero mágico de cuentos',
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: CustomPaint(
                        painter: CauldronPainter(
                          rise: _span(0.0, 0.45),
                          t: _loop.value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: title,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * title,
                      child: Text(
                        'Caldero de Cuentos',
                        textAlign: TextAlign.center,
                        style: text.displaySmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Palette.cream,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: tagline,
                    child: Text(
                      'Cuentos para soñar',
                      style: text.titleMedium!.copyWith(
                        color: Palette.amber,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  Opacity(
                    opacity: version * 0.7,
                    child: Text(
                      'v${widget.version}',
                      key: const Key('splash-version'),
                      style: text.labelSmall!.copyWith(
                        color: Palette.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// El caldero: patas, panza oscura con brillo, borde, caldo luminoso que burbujea, llamitas debajo y estrellitas
/// que suben (la luna se asoma detrás). [rise] hace que todo aparezca; [t] (0→1, en bucle) lo anima.
class CauldronPainter extends CustomPainter {
  CauldronPainter({required this.rise, required this.t});

  final double rise;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.save();
    canvas.translate(0, (1 - rise) * 40);
    final fade = rise.clamp(0.0, 1.0);

    // Luna grande detrás
    final moonC = Offset(w * 0.72, h * 0.2);
    canvas.drawCircle(
      moonC,
      w * 0.20,
      Paint()
        ..shader = RadialGradient(colors: [
          Palette.moon.withValues(alpha: 0.5 * fade),
          Palette.moon.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: moonC, radius: w * 0.20)),
    );
    canvas.drawCircle(moonC, w * 0.075,
        Paint()..color = Palette.moon.withValues(alpha: fade));
    canvas.drawCircle(moonC.translate(w * 0.03, -w * 0.012), w * 0.065,
        Paint()..color = Palette.skyMid.withValues(alpha: fade));

    final cx = w / 2;
    final potTop = h * 0.50, potBottom = h * 0.86;
    final rx = w * 0.36;

    // Llamitas
    for (var i = 0; i < 5; i++) {
      final fx = cx + (i - 2) * w * 0.085;
      final flick = 0.7 + 0.3 * math.sin(2 * math.pi * (t * 3 + i * 0.37));
      final fh = h * 0.13 * flick * (i == 2 ? 1.25 : 1);
      final path = Path()
        ..moveTo(fx - w * 0.032, potBottom + h * 0.075)
        ..quadraticBezierTo(fx - w * 0.03, potBottom + h * 0.075 - fh * 0.6, fx,
            potBottom + h * 0.075 - fh)
        ..quadraticBezierTo(fx + w * 0.03, potBottom + h * 0.075 - fh * 0.6,
            fx + w * 0.032, potBottom + h * 0.075)
        ..close();
      canvas.drawPath(path,
          Paint()..color = const Color(0xFFFF8A2A).withValues(alpha: fade));
      canvas.drawPath(
        Path()
          ..moveTo(fx - w * 0.016, potBottom + h * 0.075)
          ..quadraticBezierTo(fx, potBottom + h * 0.075 - fh * 0.75,
              fx + w * 0.016, potBottom + h * 0.075)
          ..close(),
        Paint()..color = const Color(0xFFFFD34A).withValues(alpha: fade),
      );
    }

    // Patas
    final leg = Paint()
      ..color = const Color(0xFF1B1633).withValues(alpha: fade);
    for (final dx in [-0.24, 0.24]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + w * dx, potBottom + h * 0.035),
              width: w * 0.07,
              height: h * 0.12),
          const Radius.circular(6),
        ),
        leg,
      );
    }

    // Panza
    final body = Path()
      ..moveTo(cx - rx, potTop)
      ..cubicTo(
          cx - rx * 1.12, h * 0.72, cx - rx * 0.7, potBottom, cx, potBottom)
      ..cubicTo(
          cx + rx * 0.7, potBottom, cx + rx * 1.12, h * 0.72, cx + rx, potTop)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3F86), Color(0xFF1E1840)],
        ).createShader(
            Rect.fromLTWH(cx - rx, potTop, rx * 2, potBottom - potTop)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF120F34).withValues(alpha: fade),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - rx * 0.78, potTop + h * 0.08)
        ..quadraticBezierTo(cx - rx * 0.86, h * 0.68, cx - rx * 0.5, h * 0.78),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.22 * fade),
    );

    // Caldo luminoso y borde
    final rim = Rect.fromCenter(
        center: Offset(cx, potTop), width: rx * 2.18, height: h * 0.13);
    canvas.drawOval(
        rim, Paint()..color = const Color(0xFF2E2658).withValues(alpha: fade));
    final brew = Rect.fromCenter(
        center: Offset(cx, potTop + 1), width: rx * 1.84, height: h * 0.095);
    canvas.drawOval(
      brew,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFB8FFF0).withValues(alpha: fade),
          Palette.teal.withValues(alpha: fade),
          const Color(0xFF3AA8C8).withValues(alpha: fade),
        ]).createShader(brew),
    );
    canvas.drawOval(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF120F34).withValues(alpha: fade));

    // Burbujas en el caldo
    for (var i = 0; i < 4; i++) {
      final u = (t * 1.5 + i * 0.27) % 1.0;
      final bx = cx + (i - 1.5) * w * 0.11;
      canvas.drawCircle(
        Offset(bx, potTop - u * h * 0.04),
        (3 + 4 * u) * (1 - u * 0.4),
        Paint()..color = Colors.white.withValues(alpha: 0.7 * (1 - u) * fade),
      );
    }

    // Estrellitas y vapor que suben del caldero
    for (var i = 0; i < 9; i++) {
      final u = (t * 0.9 + i / 9) % 1.0;
      final sx =
          cx + math.sin(i * 2.1 + u * 5) * w * 0.16 + (i - 4) * w * 0.012;
      final sy = potTop - u * h * 0.52;
      final a = math.sin(math.pi * u) * fade;
      if (i.isEven) {
        _star(canvas, Offset(sx, sy), 5 + 4 * (1 - u),
            Palette.amber.withValues(alpha: a));
      } else {
        canvas.drawCircle(Offset(sx, sy), 6 + 14 * u,
            Paint()..color = Colors.white.withValues(alpha: 0.16 * a));
      }
    }
    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(CauldronPainter old) => old.rise != rise || old.t != t;
}
