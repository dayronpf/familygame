import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../feedback/rating_event.dart';
import '../settings/app_settings.dart';
import 'night_background.dart';
import 'palette.dart';
import '../brand.dart';

/// El sonido de la bienvenida: una sola pista al compás de la animación (`tools/audio/build_splash_sound.py`).
abstract class SplashSound {
  Future<void> play();
}

/// Suena `assets/audio/splash.m4a` sin quitarle el foco a otra música del teléfono, y deja que la cola se apague sola
/// aunque la pantalla ya se haya ido.
class AssetSplashSound implements SplashSound {
  const AssetSplashSound({this.volume = 0.7});

  final double volume;

  @override
  Future<void> play() async {
    final p = AudioPlayer();
    try {
      await p.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build());
      await p.setReleaseMode(ReleaseMode.release);
      await p.setVolume(volume);
      unawaited(p.onPlayerComplete.first
          .timeout(const Duration(seconds: 8), onTimeout: () {})
          .whenComplete(p.dispose));
      await p.play(AssetSource('audio/splash.m4a'));
    } catch (e) {
      debugPrint('Sin sonido de bienvenida: $e');
      unawaited(p.dispose().catchError((_) {}));
    }
  }
}

/// Pantalla de bienvenida (todo centrado en vertical): una noche de cuento. Cruza una estrella fugaz, un libro aparece
/// con un rebote y se abre con rayos de luz y un estallido de chispas doradas, sale una luna llena con carita, de las
/// páginas salen volando un globo, un barquito, un cohete y estrellas (con su estela) entre luciérnagas, el nombre se
/// revela letra a letra (cada una con su chispa y su campanita) y le cruza un destello. Abajo, muy pequeña, la versión.
/// Con [sound] suena una pista al compás (si la familia no quitó los efectos y sin «reducir movimiento»). Se queda al
/// menos [minimum] y hasta que [ready] termine (así el inicio ya está cargado cuando cae el splash).
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.onFinished,
    this.ready,
    this.version = appVersion,
    this.minimum = const Duration(milliseconds: 4200),
    this.sound,
  });

  final VoidCallback onFinished;

  /// El sonido al compás (nada en las pruebas).
  final SplashSound? sound;

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
  bool _soundStarted = false;

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
    } else if (!_soundStarted && widget.sound != null) {
      _soundStarted = true;
      if (SettingsScope.maybeOf(context)?.effects ?? true) {
        unawaited(widget.sound!.play());
      }
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
                          label: 'Un libro de cuentos que se abre bajo la luna',
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: CustomPaint(
                              painter: StorybookPainter(
                                intro: _intro.value,
                                t: _loop.value,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _TitleReveal(
                          text: appName,
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
                              appTagline,
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
            // Al aterrizar, una chispa encima de la letra que crece y se apaga
            final spark = ((p - 0.55) / 0.45).clamp(0.0, 1.0);
            final sparkA =
                spark == 0 || spark == 1 ? 0.0 : math.sin(spark * math.pi);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Opacity(
                  opacity: p.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - e) * 18),
                    child: Text(letters[i], style: style),
                  ),
                ),
                if (sparkA > 0)
                  Positioned(
                    top: -6 - 8 * spark,
                    child: Opacity(
                      opacity: sparkA,
                      child: Transform.scale(
                        scale: 0.6 + 0.6 * spark,
                        child: const CustomPaint(
                            size: Size(12, 12), painter: _SparkPainter()),
                      ),
                    ),
                  ),
              ],
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

/// La chispa de cuatro puntas que sale encima de cada letra al aterrizar.
class _SparkPainter extends CustomPainter {
  const _SparkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawCircle(
        c,
        r * 0.9,
        Paint()
          ..color = const Color(0xFFFFE7A3).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFF4DC));
  }

  @override
  bool shouldRepaint(_SparkPainter old) => false;
}

/// La ilustración: un libro de cuentos aparece con un rebote y se abre; detrás sale una luna llena con carita que
/// parpadea, y de las páginas salen volando cosas de los cuentos (un globo, un barquito de papel, un cohete, un avión
/// de papel y estrellas de cinco puntas) entre luciérnagas. Sin calderos, fuego ni símbolos: juvenil y tranquila.
/// [intro] (0→1) es la entrada; [t] (0→1, en bucle) mantiene todo en movimiento mientras dura el splash.
class StorybookPainter extends CustomPainter {
  StorybookPainter({required this.intro, required this.t});

  final double intro;
  final double t;

  static const _cream = Color(0xFFFFF4DC);
  static const _page = Color(0xFFFFF9EC);
  static const _pageShade = Color(0xFFF1E3C4);
  static const _cover = Color(0xFFFF7A6B);
  static const _coverDark = Color(0xFFD9534F);
  static const _moon = Color(0xFFFFE7A3);
  static const _cheek = Color(0xFFFFA8A8);
  static const _ink = Color(0xFF3A2A5C);

  double _seg(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((intro - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final bookY = h * 0.74; // lomo del libro (abajo)
    final show = _seg(0.02, 0.22);
    final pop = _seg(0.02, 0.30, Curves.easeOutBack);
    final open = _seg(0.18, 0.42, Curves.easeInOutCubic);
    final moonUp = _seg(0.26, 0.58, Curves.easeOutBack);
    final fly = _seg(0.40, 0.62);

    final breathe = 0.5 + 0.5 * math.sin(t * math.pi * 2);

    // Resplandor suave detrás de todo (respira despacio)
    final glowR = w * (0.46 + 0.03 * breathe);
    canvas.drawCircle(
      Offset(cx, h * 0.5),
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFF8E7CFF)
              .withValues(alpha: (0.26 + 0.08 * breathe) * show),
          const Color(0xFF8E7CFF).withValues(alpha: 0),
        ]).createShader(
            Rect.fromCircle(center: Offset(cx, h * 0.5), radius: glowR)),
    );

    // Estrella fugaz que cruza el cielo al empezar
    final shoot = _seg(0.02, 0.20, Curves.easeInOutSine);
    if (shoot > 0 && shoot < 1) {
      final head = Offset(w * (0.05 + 0.75 * shoot), h * (0.10 + 0.16 * shoot));
      final dir = const Offset(-0.98, -0.21);
      final fadeS = math.sin(shoot * math.pi);
      canvas.drawLine(
        head,
        head + dir * (w * 0.22),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.white.withValues(alpha: 0.9 * fadeS),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromPoints(head, head + dir * (w * 0.22)))
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
          head,
          3.2,
          Paint()
            ..color = Colors.white.withValues(alpha: fadeS)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    }

    // Rayos de luz que salen del libro abierto y giran muy despacio
    if (open > 0.05) {
      final origin = Offset(cx, bookY - w * 0.17);
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(t * math.pi * 2 / 6);
      for (var i = 0; i < 9; i++) {
        final a = i * math.pi * 2 / 9;
        final len = w * (0.40 + 0.06 * math.sin(t * math.pi * 4 + i));
        final ray = Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(a - 0.09) * len, math.sin(a - 0.09) * len)
          ..lineTo(math.cos(a + 0.09) * len, math.sin(a + 0.09) * len)
          ..close();
        canvas.drawPath(
            ray,
            Paint()
              ..shader = RadialGradient(colors: [
                const Color(0xFFFFE7A3).withValues(alpha: 0.30 * open),
                const Color(0xFFFFE7A3).withValues(alpha: 0),
              ]).createShader(
                  Rect.fromCircle(center: Offset.zero, radius: len)));
      }
      canvas.restore();
    }

    // Luciérnagas
    for (var i = 0; i < 12; i++) {
      final a = i * 2.39996 + t * math.pi * 2 * (i.isEven ? 1 : -1) * 0.25;
      final r = w * (0.30 + 0.12 * ((i * 37) % 10) / 10);
      final p = Offset(cx + math.cos(a) * r, h * 0.48 + math.sin(a) * r * 0.65);
      final blink = 0.5 + 0.5 * math.sin(t * math.pi * 2 * 2 + i);
      canvas.drawCircle(
          p,
          2.2 + 1.2 * blink,
          Paint()
            ..color =
                const Color(0xFFFFF3A0).withValues(alpha: 0.75 * blink * show)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    // Lo que sale volando del libro: cada cosa sube por su carril, se balancea y se apaga arriba.
    final flyers = <void Function(Canvas, double)>[
      _balloon,
      _paperBoat,
      _rocket,
      _paperPlane,
      (c, s) => _star(c, s, const Color(0xFFFFD36E)),
      (c, s) => _star(c, s, const Color(0xFF8EE3C8)),
      (c, s) => _star(c, s, const Color(0xFFFFA8D2)),
    ];
    for (var i = 0; i < flyers.length; i++) {
      final phase = (t + i / flyers.length) % 1.0;
      final rise = Curves.easeOut.transform(phase);
      // Carriles a los lados (nunca por el centro, donde está la luna)
      const lanes = [-1.0, 0.85, -0.55, 1.0, 0.6, -0.9, -0.3];
      final side = lanes[i % lanes.length];
      final x = cx +
          side * w * (0.12 + 0.26 * rise) +
          math.sin(phase * math.pi * 2 + i) * 6;
      final y = bookY - h * 0.08 - rise * h * 0.62;
      final alpha =
          fly * (phase < 0.15 ? phase / 0.15 : (1 - phase).clamp(0.0, 0.5) * 2);
      if (alpha <= 0) continue;
      // Estela de chispitas detrás de lo que vuela
      for (var k = 1; k <= 3; k++) {
        canvas.drawCircle(
            Offset(x - math.sin(phase * math.pi * 2 + i) * 4 * k, y + k * 9.0),
            2.2 - k * 0.5,
            Paint()
              ..color = const Color(0xFFFFF3A0)
                  .withValues(alpha: alpha * (0.55 - k * 0.15))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      }
      canvas.saveLayer(
          null, Paint()..color = Colors.white.withValues(alpha: alpha));
      canvas.translate(x, y);
      canvas.rotate(math.sin(phase * math.pi * 2 + i) * 0.18);
      flyers[i](canvas, w * (0.055 + 0.03 * (1 - rise)));
      canvas.restore();
    }

    // La luna sale por detrás del libro, por encima de lo que vuela (nada le tapa la cara), con un halo que respira
    final moonC = Offset(cx, h * (0.56 - 0.33 * moonUp));
    if (moonUp > 0) {
      canvas.drawCircle(
          moonC,
          w * (0.26 + 0.03 * breathe),
          Paint()
            ..color = _moon.withValues(alpha: 0.10 * moonUp.clamp(0.0, 1.0))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26));
    }
    _moonFace(canvas, moonC, w * 0.15, moonUp);

    // Estallido de chispas doradas cuando el libro se abre (salen, caen un poco y se apagan)
    final burst = _seg(0.28, 0.66, Curves.linear);
    if (burst > 0 && burst < 1) {
      final origin = Offset(cx, bookY - w * 0.16);
      for (var i = 0; i < 40; i++) {
        final ang = -math.pi * (0.08 + 0.84 * ((i * 0.6180339) % 1.0));
        final speed = w * (0.30 + 0.30 * ((i * 37) % 11) / 11);
        final e = Curves.easeOutCubic.transform(burst);
        final p = origin +
            Offset(math.cos(ang) * speed * e,
                math.sin(ang) * speed * e + w * 0.10 * burst * burst);
        final life = (1 - burst) * (burst < 0.08 ? burst / 0.08 : 1);
        final colors = [
          const Color(0xFFFFD36E),
          const Color(0xFFFFF3A0),
          const Color(0xFFFFA8D2),
          const Color(0xFF8EE3C8),
        ];
        final c = colors[i % colors.length];
        if (i % 3 == 0) {
          _star(canvas, 0, c,
              at: p, radius: 6.0 * (0.6 + 0.4 * life), alpha: life);
        } else {
          canvas.drawCircle(
              p,
              2.6 + 1.8 * life,
              Paint()
                ..color = c.withValues(alpha: life)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0));
        }
      }
    }

    // El libro, con su rebote (se escala desde el lomo). Cerrado se centra; al abrirse, el lomo queda en medio.
    canvas.save();
    canvas.translate(cx - w * 0.15 * (1 - open), bookY);
    final sc = 0.4 + 0.6 * pop;
    canvas.scale(sc, sc);
    _book(canvas, w, open, show);
    canvas.restore();
  }

  void _moonFace(Canvas canvas, Offset c, double r, double k) {
    if (k <= 0) return;
    final a = k.clamp(0.0, 1.0);
    canvas.drawCircle(
        c,
        r * 1.6,
        Paint()
          ..color = _moon.withValues(alpha: 0.18 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawCircle(c, r, Paint()..color = _moon.withValues(alpha: a));
    // Cráteres suaves
    final crater = Paint()
      ..color = const Color(0xFFF5D27A).withValues(alpha: 0.7 * a);
    canvas.drawCircle(c + Offset(-r * 0.45, -r * 0.42), r * 0.16, crater);
    canvas.drawCircle(c + Offset(r * 0.5, -r * 0.2), r * 0.1, crater);
    // Ojos que parpadean de vez en cuando
    final blinkPhase = (t * 2) % 1.0;
    final closed = blinkPhase > 0.92;
    final eye = Paint()
      ..color = _ink.withValues(alpha: a)
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..style = closed ? PaintingStyle.stroke : PaintingStyle.fill;
    for (final dx in [-0.33, 0.33]) {
      final e = c + Offset(dx * r, -r * 0.02);
      if (closed) {
        canvas.drawLine(e - Offset(r * 0.1, 0), e + Offset(r * 0.1, 0), eye);
      } else {
        canvas.drawCircle(e, r * 0.09, eye);
        canvas.drawCircle(e + Offset(r * 0.03, -r * 0.03), r * 0.03,
            Paint()..color = Colors.white.withValues(alpha: a));
      }
    }
    canvas.drawCircle(c + Offset(-r * 0.55, r * 0.25), r * 0.13,
        Paint()..color = _cheek.withValues(alpha: 0.8 * a));
    canvas.drawCircle(c + Offset(r * 0.55, r * 0.25), r * 0.13,
        Paint()..color = _cheek.withValues(alpha: 0.8 * a));
    canvas.drawArc(
      Rect.fromCenter(
          center: c + Offset(0, r * 0.2), width: r * 0.5, height: r * 0.36),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      Paint()
        ..color = _ink.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round,
    );
  }

  /// El libro abierto, dibujado con el lomo en (0, 0). [open] 0 = cerrado (se ve la tapa), 1 = abierto.
  void _book(Canvas canvas, double w, double open, double alpha) {
    final pw = w * 0.30; // ancho de cada página
    final ph = w * 0.30; // alto
    final o = Paint()..color = _coverDark.withValues(alpha: alpha);
    // Tapa trasera (asoma por debajo de las páginas)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(
              -pw * (0.15 + 0.92 * open) - 6, -ph - 4, pw * 1.07 + 6, 8),
          const Radius.circular(14)),
      o,
    );
    // Página derecha (siempre abierta) con renglones
    _pageShape(canvas, pw, ph, 1, alpha);
    // Página izquierda: se despliega desde el lomo
    if (open > 0.02) {
      canvas.save();
      canvas.scale(-open, 1);
      _pageShape(canvas, pw, ph, open, alpha);
      canvas.restore();
    }
    // Tapa delantera: mientras está cerrado se ve encima; al abrirse se pliega hacia la izquierda
    final coverW = pw * (1 - open);
    if (coverW > 1) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTRB(-2, -ph - 2, coverW + 4, 4), const Radius.circular(12));
      canvas.drawRRect(r, Paint()..color = _cover.withValues(alpha: alpha));
      if (coverW > pw * 0.5) {
        _star(canvas, 0, Colors.white,
            at: Offset(coverW * 0.55, -ph * 0.5),
            radius: pw * 0.16 * (coverW / pw),
            alpha: alpha * 0.9);
      }
    }
    // Lomo
    canvas.drawLine(
        const Offset(0, 4),
        Offset(0, -ph),
        Paint()
          ..color = _pageShade.withValues(alpha: alpha)
          ..strokeWidth = 3);
  }

  void _pageShape(Canvas canvas, double pw, double ph, double k, double alpha) {
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(pw * 0.5, -ph * 0.06, pw, 0)
      ..lineTo(pw, -ph)
      ..quadraticBezierTo(pw * 0.5, -ph * 1.08, 0, -ph)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: [_pageShade, _page])
            .createShader(Rect.fromLTWH(0, -ph, pw * 0.3, ph))
        ..color = _page.withValues(alpha: alpha),
    );
    final line = Paint()
      ..color = const Color(0xFFCBB892).withValues(alpha: 0.7 * alpha * k)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = -ph * (0.78 - i * 0.14);
      final len = pw * (i == 4 ? 0.45 : 0.72);
      canvas.drawLine(Offset(pw * 0.14, y), Offset(pw * 0.14 + len, y), line);
    }
  }

  // ------------------------------------------------------------- lo que vuela

  /// Estrella de cinco puntas con las puntas redondeadas.
  void _star(Canvas canvas, double s, Color color,
      {Offset at = Offset.zero, double? radius, double alpha = 1}) {
    final r = radius ?? s;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final ang = -math.pi / 2 + i * math.pi / 5;
      final rad = i.isEven ? r : r * 0.48;
      final p = at + Offset(math.cos(ang) * rad, math.sin(ang) * rad);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = r * 0.25
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = r * 0.25
          ..style = PaintingStyle.stroke);
  }

  void _balloon(Canvas canvas, double s) {
    canvas.drawLine(
        Offset(0, s * 0.9),
        Offset(0, s * 1.7),
        Paint()
          ..color = _cream
          ..strokeWidth = 1.5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, s * 1.8), width: s * 0.6, height: s * 0.4),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFFC98A5A));
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s * 1.9),
        Paint()..color = const Color(0xFF6FC3FF));
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.6, height: s * 1.9),
        Paint()..color = const Color(0xFFFFD36E));
  }

  void _paperBoat(Canvas canvas, double s) {
    final hull = Path()
      ..moveTo(-s * 1.1, 0)
      ..lineTo(s * 1.1, 0)
      ..lineTo(s * 0.7, s * 0.6)
      ..lineTo(-s * 0.7, s * 0.6)
      ..close();
    final sail = Path()
      ..moveTo(-s * 0.1, -s * 1.2)
      ..lineTo(s * 0.7, 0)
      ..lineTo(-s * 0.1, 0)
      ..close();
    canvas.drawPath(sail, Paint()..color = _cream);
    canvas.drawPath(hull, Paint()..color = const Color(0xFF4FC3A1));
  }

  void _rocket(Canvas canvas, double s) {
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, s * 1.15), width: s * 0.5, height: s * 0.8),
        Paint()..color = const Color(0xFFFFB347));
    final fin = Paint()..color = const Color(0xFFFF7A6B);
    canvas.drawPath(
        Path()
          ..moveTo(-s * 0.45, s * 0.3)
          ..lineTo(-s * 0.85, s * 0.95)
          ..lineTo(-s * 0.35, s * 0.8)
          ..close(),
        fin);
    canvas.drawPath(
        Path()
          ..moveTo(s * 0.45, s * 0.3)
          ..lineTo(s * 0.85, s * 0.95)
          ..lineTo(s * 0.35, s * 0.8)
          ..close(),
        fin);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: s * 0.9, height: s * 1.9),
            Radius.circular(s * 0.45)),
        Paint()..color = _cream);
    canvas.drawCircle(Offset(0, -s * 0.2), s * 0.22,
        Paint()..color = const Color(0xFF6FC3FF));
  }

  void _paperPlane(Canvas canvas, double s) {
    canvas.drawPath(
        Path()
          ..moveTo(s * 1.2, 0)
          ..lineTo(-s * 1.0, -s * 0.6)
          ..lineTo(-s * 0.4, 0)
          ..close(),
        Paint()..color = _cream);
    canvas.drawPath(
        Path()
          ..moveTo(s * 1.2, 0)
          ..lineTo(-s * 0.4, 0)
          ..lineTo(-s * 0.7, s * 0.55)
          ..close(),
        Paint()..color = const Color(0xFFDCCFFF));
  }

  @override
  bool shouldRepaint(StorybookPainter old) => old.intro != intro || old.t != t;
}
