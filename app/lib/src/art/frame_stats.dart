import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Mide el rendimiento real de los fotogramas (fps, tiempo de dibujo, fotogramas lentos).
class FrameStats {
  FrameStats({this.window = 90});

  final int window;
  final ValueNotifier<String> label = ValueNotifier('midiendo…');

  final List<double> _ms = [];
  final List<int> _finish = [];
  Timer? _timer;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _timer =
        Timer.periodic(const Duration(milliseconds: 500), (_) => _publish());
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _timer?.cancel();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final t in timings) {
      _ms.add(t.totalSpan.inMicroseconds / 1000);
      _finish.add(t.timestampInMicroseconds(ui.FramePhase.rasterFinish));
    }
    while (_ms.length > window) {
      _ms.removeAt(0);
      _finish.removeAt(0);
    }
  }

  void _publish() {
    if (_ms.length < 10) return;
    final avg = _ms.reduce((a, b) => a + b) / _ms.length;
    final worst = _ms.reduce((a, b) => a > b ? a : b);
    final slow = _ms.where((m) => m > 16.7).length * 100 / _ms.length;
    final span = (_finish.last - _finish.first) / 1e6;
    final fps = span > 0 ? (_finish.length - 1) / span : 0;
    final mode = kReleaseMode
        ? ''
        : '\n⚠ ${kProfileMode ? 'perfil' : 'debug'}: mide con --release';
    label.value = '${fps.toStringAsFixed(0)} fps · ${avg.toStringAsFixed(1)} ms'
        ' (máx ${worst.toStringAsFixed(0)})\n${slow.toStringAsFixed(0)} % lentos$mode';
  }
}
