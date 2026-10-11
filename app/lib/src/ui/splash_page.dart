import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../feedback/rating_event.dart';
import 'night_background.dart';
import 'palette.dart';

/// Pantalla de bienvenida (todo centrado en vertical): una noche de cuento; la luna sale, el caldero aparece con un
/// rebote y se enciende, de él salen volando cuentos (un libro, un castillo, una corona, un sombrero de mago) entre
/// luciérnagas, el nombre se revela letra a letra con un destello y, abajo y muy pequeña, la versión. Se queda al
/// menos [minimum] y hasta que [ready] termine (así el inicio ya está cargado cuando cae el splash).
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.onFinished,
    this.ready,
    this.version = appVersion,
    this.minimum = const Duration(milliseconds: 3600),
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
  double _span(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_intro.value - a) / (b - a)).clamp(0.0, 1.0));

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
              final tagline = _span(0.66, 0.88);
              final version = _span(0.8, 1.0);
              return Stack(
                children: [
                  // El conjunto (dibujo + nombre + lema) queda en el centro exacto de la pantalla
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'Un caldero mágico de cuentos',
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: CustomPaint(
                              painter: CauldronPainter(
                                intro: _intro.value,
                                t: _loop.value,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _TitleReveal(
                          text: 'Caldero de Cuentos',
                          progress: _span(0.40, 0.72, Curves.easeOut),
                          shimmer: _span(0.70, 0.98, Curves.easeInOut),
                          style: text.displaySmall!.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Palette.cream,
                            letterSpacing: 0.5,
                            fontSize: 34,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: tagline,
                          child: Transform.translate(
                            offset: Offset(0, (1 - tagline) * 8),
                            child: Text(
                              'Cuentos para soñar',
                              style: text.titleMedium!.copyWith(
                                color: Palette.amber,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Opacity(
                      opacity: version * 0.7,
                      child: Text(
                        'v${widget.version}',
                        key: const Key('splash-version'),
                        textAlign: TextAlign.center,
                        style: text.labelSmall!.copyWith(
                          color: Palette.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// El nombre se revela letra a letra (cada una sube y aparece) y después le cruza un destello de luz.
class _TitleReveal extends StatelessWidget {
  const _TitleReveal({
    required this.text,
    required this.progress,
    required this.shimmer,
    required this.style,
  });

  final String text;
  final double progress; // 0→1: letras apareciendo
  final double shimmer; // 0→1: el destello cruza
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final letters = text.characters.toList();
    final n = letters.length;
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++)
          () {
            // Cada letra tiene su franja: las primeras aparecen antes
            final start = i / n * 0.7;
            final p = ((progress - start) / 0.3).clamp(0.0, 1.0);
            final e = Curves.easeOutBack.transform(p);
            return Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - e) * 18),
                child: Text(letters[i], style: style),
              ),
            );
          }(),
      ],
    );
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) {
          final c =
              -0.3 + shimmer * 1.6; // el destello va de izquierda a derecha
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white
                  .withValues(alpha: shimmer > 0 && shimmer < 1 ? 0.85 : 0),
              Colors.white.withValues(alpha: 0),
            ],
            stops: [
              (c - 0.14).clamp(0.0, 1.0),
              c.clamp(0.0, 1.0),
              (c + 0.14).clamp(0.0, 1.0),
            ],
          ).createShader(r);
        },
        child: FittedBox(fit: BoxFit.scaleDown, child: title),
      ),
    );
  }
}

/// La ilustración: la luna sale, el caldero aparece con un rebote y se enciende (patas, panza con brillo, borde,
/// caldo luminoso que burbujea, llamitas), y de él suben cuentos y estrellitas entre luciérnagas.
/// [intro] (0→1) es la entrada; [t] (0→1, en bucle) mantiene todo en movimiento mientras dura el splash.
class CauldronPainter extends CustomPainter {
  CauldronPainter({required this.intro, required this.t});

  final double intro;
  final double t;

  double _seg(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((intro - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final potTop = h * 0.55, potBottom = h * 0.88;
    final rx = w * 0.34;

    final show = _seg(0.04, 0.26); // opacidad del caldero
    final pop = _seg(0.04, 0.34, Curves.easeOutBack); // rebote al aparecer
    final fire = _seg(0.2, 0.42); // las llamas se encienden
    final glow = 0.6 + 0.4 * math.sin(2 * math.pi * t * 2);

    // Resplandor cálido detrás del caldero
    final halo = Offset(cx, potTop - h * 0.04);
    canvas.drawCircle(
      halo,
      w * 0.5,
      Paint()
        ..shader = RadialGradient(colors: [
          Palette.teal.withValues(alpha: 0.20 * fire * glow),
          Palette.teal.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: halo, radius: w * 0.5)),
    );

    // Luna: sale desde abajo y se enciende; su halo respira
    final moonUp = _seg(0.0, 0.35);
    final moonC = Offset(w * 0.74, h * (0.34 - 0.16 * moonUp));
    canvas.drawCircle(
      moonC,
      w * (0.19 + 0.015 * glow),
      Paint()
        ..shader = RadialGradient(colors: [
          Palette.moon.withValues(alpha: 0.5 * moonUp),
          Palette.moon.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: moonC, radius: w * 0.21)),
    );
    canvas.drawCircle(moonC, w * 0.075,
        Paint()..color = Palette.moon.withValues(alpha: moonUp));
    canvas.drawCircle(moonC.translate(w * 0.03, -w * 0.012), w * 0.065,
        Paint()..color = Palette.skyMid.withValues(alpha: moonUp));

    // Luciérnagas que flotan alrededor
    for (var i = 0; i < 9; i++) {
      final a = 2 * math.pi * (t + i / 9) + i;
      final fx =
          cx + math.cos(a * (1 + (i % 3) * 0.3)) * w * (0.30 + 0.06 * (i % 3));
      final fy = h * 0.55 + math.sin(a * 1.3) * h * 0.22 - h * 0.05;
      final tw = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 3 + i * 0.31));
      final al = _seg(0.3, 0.6) * (0.25 + 0.6 * tw);
      canvas.drawCircle(Offset(fx, fy), 6,
          Paint()..color = Palette.amber.withValues(alpha: 0.18 * al));
      canvas.drawCircle(Offset(fx, fy), 1.8,
          Paint()..color = Palette.moon.withValues(alpha: al));
    }

    // Todo el caldero con su rebote (se escala desde la base)
    canvas.save();
    final s = 0.55 + 0.45 * pop;
    canvas.translate(cx, potBottom);
    canvas.scale(s);
    canvas.translate(-cx, -potBottom);
    canvas.translate(0, (1 - show) * 24);
    _pot(canvas, size, show, fire, glow, cx, potTop, potBottom, rx);
    canvas.restore();

    // Cuentos que salen del caldero y suben, girando, hasta apagarse
    final out = _seg(0.34, 0.5);
    for (var i = 0; i < 4; i++) {
      final u = (t * 0.55 + i / 4) % 1.0;
      // Cada cuento sale hacia un lado distinto (el castillo y el sombrero hacia la derecha, sin pisar la luna)
      final side = const [-1.0, 0.5, -0.5, 0.9][i];
      final x = cx +
          math.sin(u * math.pi * 1.4) * w * 0.26 * side +
          side * w * 0.04 * u;
      final y = potTop - Curves.easeOut.transform(u) * h * 0.50;
      final a = math.sin(math.pi * u).clamp(0.0, 1.0) * out;
      final r = w * (0.045 + 0.06 * math.sin(math.pi * math.min(u * 1.6, 1.0)));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(u * math.pi * 2 + i) * 0.5);
      switch (i) {
        case 0:
          _book(canvas, r, a);
        case 1:
          _castle(canvas, r, a);
        case 2:
          _crown(canvas, r, a);
        default:
          _hat(canvas, r, a);
      }
      canvas.restore();
      // Estela de chispitas
      for (var k = 1; k <= 3; k++) {
        final uu = (u - k * 0.04).clamp(0.0, 1.0);
        final sx = cx +
            math.sin(uu * math.pi * 1.4) * w * 0.26 * side +
            side * w * 0.04 * uu;
        final sy = potTop - Curves.easeOut.transform(uu) * h * 0.50;
        canvas.drawCircle(
            Offset(sx, sy),
            2.4 - k * 0.5,
            Paint()
              ..color = Palette.amber.withValues(alpha: a * (0.6 - k * 0.15)));
      }
    }

    // Estrellitas y vapor que suben
    for (var i = 0; i < 8; i++) {
      final u = (t * 0.9 + i / 8) % 1.0;
      final sx =
          cx + math.sin(i * 2.1 + u * 5) * w * 0.17 + (i - 4) * w * 0.012;
      final sy = potTop - u * h * 0.5;
      final a = math.sin(math.pi * u) * fire;
      if (i.isEven) {
        _star(canvas, Offset(sx, sy), 4 + 4 * (1 - u),
            Palette.amber.withValues(alpha: a));
      } else {
        canvas.drawCircle(Offset(sx, sy), 6 + 14 * u,
            Paint()..color = Colors.white.withValues(alpha: 0.13 * a));
      }
    }
  }

  void _pot(Canvas canvas, Size size, double fade, double fire, double glow,
      double cx, double potTop, double potBottom, double rx) {
    final w = size.width, h = size.height;
    // Llamitas
    for (var i = 0; i < 5; i++) {
      final fx = cx + (i - 2) * w * 0.085;
      final flick = 0.7 + 0.3 * math.sin(2 * math.pi * (t * 3 + i * 0.37));
      final fh = h * 0.12 * flick * (i == 2 ? 1.25 : 1) * fire;
      final base = potBottom + h * 0.07;
      canvas.drawPath(
        Path()
          ..moveTo(fx - w * 0.032, base)
          ..quadraticBezierTo(fx - w * 0.03, base - fh * 0.6, fx, base - fh)
          ..quadraticBezierTo(
              fx + w * 0.03, base - fh * 0.6, fx + w * 0.032, base)
          ..close(),
        Paint()..color = const Color(0xFFFF8A2A).withValues(alpha: fade),
      );
      canvas.drawPath(
        Path()
          ..moveTo(fx - w * 0.016, base)
          ..quadraticBezierTo(fx, base - fh * 0.75, fx + w * 0.016, base)
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
          cx - rx * 1.12, h * 0.74, cx - rx * 0.7, potBottom, cx, potBottom)
      ..cubicTo(
          cx + rx * 0.7, potBottom, cx + rx * 1.12, h * 0.74, cx + rx, potTop)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A3F86).withValues(alpha: fade),
            const Color(0xFF1E1840).withValues(alpha: fade),
          ],
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
        ..quadraticBezierTo(cx - rx * 0.86, h * 0.7, cx - rx * 0.5, h * 0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.22 * fade),
    );
    // Borde y caldo luminoso (el brillo respira)
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
          Color.lerp(const Color(0xFFB8FFF0), Colors.white, 0.4 * glow)!
              .withValues(alpha: fade),
          Palette.teal.withValues(alpha: fade),
          const Color(0xFF3AA8C8).withValues(alpha: fade),
        ]).createShader(brew),
    );
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF120F34).withValues(alpha: fade),
    );
    // Burbujas que suben y revientan en el caldo
    for (var i = 0; i < 5; i++) {
      final u = (t * 1.6 + i * 0.23) % 1.0;
      final bx = cx + (i - 2) * w * 0.09;
      canvas.drawCircle(
        Offset(bx, potTop + 2 - u * h * 0.05),
        (2.5 + 4.5 * u) * (1 - u * 0.3),
        Paint()
          ..style = u > 0.8 ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.75 * (1 - u * 0.6) * fade),
      );
    }
  }

  // ----------------------------------------------------- iconos de cuento
  void _book(Canvas c, double r, double a) {
    final page = Paint()..color = Palette.cream.withValues(alpha: a);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Palette.amber.withValues(alpha: a);
    final l = Path()
      ..moveTo(0, -r * 0.5)
      ..quadraticBezierTo(-r * 0.7, -r * 0.8, -r * 1.3, -r * 0.5)
      ..lineTo(-r * 1.3, r * 0.6)
      ..quadraticBezierTo(-r * 0.7, r * 0.3, 0, r * 0.6)
      ..close();
    final rr = Path()
      ..moveTo(0, -r * 0.5)
      ..quadraticBezierTo(r * 0.7, -r * 0.8, r * 1.3, -r * 0.5)
      ..lineTo(r * 1.3, r * 0.6)
      ..quadraticBezierTo(r * 0.7, r * 0.3, 0, r * 0.6)
      ..close();
    c.drawPath(l, page);
    c.drawPath(rr, page);
    c.drawPath(l, edge);
    c.drawPath(rr, edge);
  }

  void _castle(Canvas c, double r, double a) {
    final p = Paint()..color = const Color(0xFFC9C0F5).withValues(alpha: a);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF3A2A8A).withValues(alpha: a);
    final body = Path()
      ..moveTo(-r, r * 0.8)
      ..lineTo(-r, -r * 0.3)
      ..lineTo(-r * 0.7, -r * 0.3)
      ..lineTo(-r * 0.7, -r * 0.6)
      ..lineTo(-r * 0.25, -r * 0.6)
      ..lineTo(-r * 0.25, -r * 0.3)
      ..lineTo(r * 0.25, -r * 0.3)
      ..lineTo(r * 0.25, -r * 0.6)
      ..lineTo(r * 0.7, -r * 0.6)
      ..lineTo(r * 0.7, -r * 0.3)
      ..lineTo(r, -r * 0.3)
      ..lineTo(r, r * 0.8)
      ..close();
    c.drawPath(body, p);
    c.drawPath(body, line);
    c.drawPath(
      Path()
        ..moveTo(-r * 0.25, r * 0.8)
        ..lineTo(-r * 0.25, r * 0.15)
        ..quadraticBezierTo(0, -r * 0.2, r * 0.25, r * 0.15)
        ..lineTo(r * 0.25, r * 0.8)
        ..close(),
      Paint()..color = const Color(0xFF3A2A8A).withValues(alpha: a),
    );
  }

  void _crown(Canvas c, double r, double a) {
    final p = Paint()..color = Palette.amber.withValues(alpha: a);
    final path = Path()
      ..moveTo(-r, r * 0.6)
      ..lineTo(-r, -r * 0.5)
      ..lineTo(-r * 0.45, r * 0.05)
      ..lineTo(0, -r * 0.8)
      ..lineTo(r * 0.45, r * 0.05)
      ..lineTo(r, -r * 0.5)
      ..lineTo(r, r * 0.6)
      ..close();
    c.drawPath(path, p);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF8A5A00).withValues(alpha: a),
    );
    c.drawCircle(Offset(0, r * 0.25), r * 0.14,
        Paint()..color = const Color(0xFFE05A8B).withValues(alpha: a));
  }

  void _hat(Canvas c, double r, double a) {
    final p = Paint()..color = const Color(0xFF6B4FD8).withValues(alpha: a);
    c.drawPath(
      Path()
        ..moveTo(-r * 0.7, r * 0.5)
        ..quadraticBezierTo(-r * 0.2, -r * 0.2, r * 0.25, -r * 1.2)
        ..quadraticBezierTo(r * 0.5, -r * 0.1, r * 0.7, r * 0.5)
        ..close(),
      p,
    );
    c.drawOval(
        Rect.fromCenter(
            center: Offset(0, r * 0.52), width: r * 2.4, height: r * 0.5),
        Paint()..color = const Color(0xFF4A3AB0).withValues(alpha: a));
    _star(c, Offset(0, -r * 0.1), r * 0.22, Palette.amber.withValues(alpha: a));
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
  bool shouldRepaint(CauldronPainter old) => old.intro != intro || old.t != t;
}
