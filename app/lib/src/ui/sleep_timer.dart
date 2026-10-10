import 'dart:async';

import 'package:flutter/material.dart';

/// Botón de la lunita para dormir: el adulto elige cuántos minutos más suena el cuento y, al cumplirse, se
/// llama a [onExpire] (la página detiene la voz y el sonido de fondo) y se desea «Dulces sueños».
class SleepTimerButton extends StatefulWidget {
  const SleepTimerButton({
    super.key,
    required this.onExpire,
    this.color = Colors.white,
    this.iconSize,
    this.onPicked,
    this.minutesToDuration = _minutes,
  });

  final VoidCallback onExpire;
  final Color color;
  final double? iconSize;

  /// Se llama al elegir (o quitar) el temporizador; la pantalla del holograma lo usa para mantener los controles.
  final VoidCallback? onPicked;

  /// Cómo se convierten los minutos elegidos en tiempo (las pruebas lo acortan).
  final Duration Function(int minutes) minutesToDuration;

  static Duration _minutes(int m) => Duration(minutes: m);

  static const List<int> options = [10, 20, 30];

  @override
  State<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends State<SleepTimerButton> {
  Timer? _timer;
  int? _minutes;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _set(int? minutes) {
    _timer?.cancel();
    setState(() => _minutes = minutes);
    widget.onPicked?.call();
    if (minutes == null) return;
    _timer = Timer(widget.minutesToDuration(minutes), () {
      if (!mounted) return;
      setState(() => _minutes = null);
      widget.onExpire();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('🌙 Dulces sueños'),
          duration: Duration(seconds: 6),
        ),
      );
    });
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
