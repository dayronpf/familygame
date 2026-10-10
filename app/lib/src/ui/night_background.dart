import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Fondo de noche de cuento: degradado índigo y estrellitas que titilan despacio
/// (quietas si el sistema pide «reducir movimiento»).
class NightBackground extends StatefulWidget {
  const NightBackground({super.key, required this.child, this.stars = 46});

  final Widget child;
  final int stars;

  @override
  State<NightBackground> createState() => _NightBackgroundState();
}

class _NightBackgroundState extends State<NightBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  late final List<_Star> _stars = _makeStars(widget.stars);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static List<_Star> _makeStars(int n) {
    final r = math.Random(7);
    return [
      for (var i = 0; i < n; i++)
        _Star(r.nextDouble(), r.nextDouble() * 0.9, 0.6 + r.nextDouble() * 1.6,
            r.nextDouble()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.skyTop, Palette.skyMid, Palette.skyLow],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _StarsPainter(_stars, _c)),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Star {
  const _Star(this.x, this.y, this.r, this.phase);
  final double x, y, r, phase;
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.stars, this.t) : super(repaint: t);

  final List<_Star> stars;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in stars) {
      final a = 0.35 +
          0.55 * (0.5 + 0.5 * math.sin(2 * math.pi * (t.value + s.phase)));
      p.color = Palette.moon.withValues(alpha: a);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, p);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}
