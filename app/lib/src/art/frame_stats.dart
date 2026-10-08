import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Un fotograma medido: cuánto tardó la interfaz (build) y el dibujo (raster), y cuándo terminó.
class FrameSample {
  const FrameSample(
      {required this.buildMs, required this.rasterMs, required this.finishUs});

  final double buildMs, rasterMs;
  final int finishUs;

  /// Flutter encadena ambos pasos en paralelo: un fotograma «pierde su turno» si CUALQUIERA excede el presupuesto.
  double get worstStageMs => buildMs > rasterMs ? buildMs : rasterMs;
}

class FrameSummary {
  const FrameSummary({
    required this.count,
    required this.fps,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.worstMs,
    required this.overBudgetPercent,
    required this.budgetMs,
  });

  final int count;
  final double fps,
      avgBuildMs,
      avgRasterMs,
      worstMs,
      overBudgetPercent,
      budgetMs;
}

/// Resume una ventana de fotogramas frente al presupuesto de la pantalla (1000 / Hz milisegundos).
FrameSummary summarizeFrames(List<FrameSample> s,
    {required double refreshRateHz}) {
  final budget = 1000 / refreshRateHz;
  if (s.isEmpty) {
    return FrameSummary(
      count: 0,
      fps: 0,
      avgBuildMs: 0,
      avgRasterMs: 0,
      worstMs: 0,
      overBudgetPercent: 0,
      budgetMs: budget,
    );
  }
  final span = (s.last.finishUs - s.first.finishUs) / 1e6;
  return FrameSummary(
    count: s.length,
    fps: span > 0 ? (s.length - 1) / span : 0,
    avgBuildMs: s.fold<double>(0, (a, f) => a + f.buildMs) / s.length,
    avgRasterMs: s.fold<double>(0, (a, f) => a + f.rasterMs) / s.length,
    worstMs:
        s.fold<double>(0, (a, f) => f.worstStageMs > a ? f.worstStageMs : a),
    overBudgetPercent:
        s.where((f) => f.worstStageMs > budget).length * 100 / s.length,
    budgetMs: budget,
  );
}

/// Texto del recuadro. `debugNote` avisa de que no se está midiendo una versión release.
String formatSummary(FrameSummary m,
    {required double refreshRateHz, String debugNote = ''}) {
  return '${m.fps.toStringAsFixed(0)} fps · UI ${m.avgBuildMs.toStringAsFixed(1)} ms'
      ' · dibujo ${m.avgRasterMs.toStringAsFixed(1)} ms\n'
      'peor ${m.worstMs.toStringAsFixed(0)} ms · ${m.overBudgetPercent.toStringAsFixed(0)} % '
      'sobre ${m.budgetMs.toStringAsFixed(1)} ms (${refreshRateHz.toStringAsFixed(0)} Hz)$debugNote';
}

/// Mide el rendimiento real de los fotogramas en el teléfono.
class FrameStats {
  FrameStats({this.window = 240});

  final int window;
  final ValueNotifier<String> label = ValueNotifier('midiendo…');

  final List<FrameSample> _samples = [];
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
      _samples.add(
        FrameSample(
          buildMs: t.buildDuration.inMicroseconds / 1000,
          rasterMs: t.rasterDuration.inMicroseconds / 1000,
          finishUs: t.timestampInMicroseconds(ui.FramePhase.rasterFinish),
        ),
      );
    }
    if (_samples.length > window) {
      _samples.removeRange(0, _samples.length - window);
    }
  }

  /// Frecuencia real de la pantalla (60, 90, 120…); 60 si no se puede saber.
  double _refreshRate() {
    final views = SchedulerBinding.instance.platformDispatcher.views;
    final hz = views.isEmpty ? 0.0 : views.first.display.refreshRate;
    return hz >= 30 ? hz : 60;
  }

  void _publish() {
    if (_samples.length < 10) return;
    final hz = _refreshRate();
    final note = kReleaseMode
        ? ''
        : '\n⚠ ${kProfileMode ? 'perfil' : 'debug'}: mide con --release';
    label.value = formatSummary(summarizeFrames(_samples, refreshRateHz: hz),
        refreshRateHz: hz, debugNote: note);
  }
}
