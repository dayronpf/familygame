import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Botón de la lunita para dormir: el adulto elige cuántos minutos más suena el cuento. **No corta de golpe:** en
/// los últimos [fadeDuration] (90 s; menos si el temporizador es muy corto) avisa con [onFade] (de 1 a 0, una vez
/// por [fadeTick]) para que la página baje el volumen de la voz y de la música y el brillo de la pantalla. Al
/// cumplirse llama a [onExpire] (detiene la voz y el sonido de fondo) y desea «Dulces sueños». Si se quita o se
/// cambia el temporizador a mitad del fundido se llama a [onCancel] para devolver volumen y brillo.
class SleepTimerButton extends StatefulWidget {
  const SleepTimerButton({
    super.key,
    required this.onExpire,
    this.onFade,
    this.onCancel,
    this.fadeDuration = const Duration(seconds: 90),
    this.fadeTick = const Duration(seconds: 1),
    this.color = Colors.white,
    this.iconSize,
    this.onPicked,
    this.onArmed,
    this.minutesToDuration = _minutes,
  });

  final VoidCallback onExpire;

  /// Nivel del fundido: 1 = todo como siempre, 0 = en silencio y a oscuras.
  final void Function(double level)? onFade;
  final VoidCallback? onCancel;
  final Duration fadeDuration;
  final Duration fadeTick;
  final Color color;
  final double? iconSize;

  /// Se llama al elegir (o quitar) el temporizador; la pantalla del holograma lo usa para mantener los controles.
  final VoidCallback? onPicked;

  /// Se llama con `true` al armar el temporizador y con `false` al quitarlo: mientras está armado el cuento no
  /// hace preguntas al niño (quien arma la lunita quiere que se duerma).
  final ValueChanged<bool>? onArmed;

  /// Cómo se convierten los minutos elegidos en tiempo (las pruebas lo acortan).
  final Duration Function(int minutes) minutesToDuration;

  static Duration _minutes(int m) => Duration(minutes: m);

  static const List<int> options = [10, 20, 30];

  @override
  State<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends State<SleepTimerButton> {
  Timer? _timer;
  Timer? _fadeTimer;
  int? _minutes;
  bool _fading = false;

  @override
  void dispose() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _set(int? minutes) {
    _timer?.cancel();
    _fadeTimer?.cancel();
    if (_fading) {
      _fading = false;
      widget.onCancel?.call(); // estaba bajando: vuelve el volumen y el brillo
    }
    setState(() => _minutes = minutes);
    widget.onPicked?.call();
    widget.onArmed?.call(minutes != null);
    if (minutes == null) return;
    final total = widget.minutesToDuration(minutes);
    final fade =
        total < widget.fadeDuration * 2 ? total * 0.5 : widget.fadeDuration;
    _timer = Timer(total - fade, () => _startFade(fade));
  }

  void _startFade(Duration fade) {
    if (!mounted) return;
    final tick = widget.fadeTick.inMicroseconds;
    final steps = math.max(1, fade.inMicroseconds ~/ math.max(1, tick));
    var i = 0;
    _fading = true;
    _fadeTimer = Timer.periodic(widget.fadeTick, (t) {
      if (!mounted) return t.cancel();
      i++;
      final level = (1 - i / steps).clamp(0.0, 1.0);
      widget.onFade?.call(level);
      if (i >= steps) {
        t.cancel();
        _expire();
      }
    });
  }

  void _expire() {
    _fading = false;
    setState(() => _minutes = null);
    widget.onExpire();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('🌙 Dulces sueños'),
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = _minutes != null;
    return PopupMenuButton<int>(
      key: const Key('sleep-timer'),
      tooltip: on ? 'Dormir en $_minutes min' : 'Temporizador para dormir',
      icon: Icon(
        on ? Icons.bedtime : Icons.bedtime_outlined,
        color: on ? const Color(0xFFFFC857) : widget.color,
        size: widget.iconSize,
      ),
      onSelected: (m) => _set(m == 0 ? null : m),
      itemBuilder: (_) => [
        for (final m in SleepTimerButton.options)
          PopupMenuItem(value: m, child: Text('Dormir en $m minutos')),
        if (on)
          const PopupMenuItem(value: 0, child: Text('Quitar temporizador')),
      ],
    );
  }
}
