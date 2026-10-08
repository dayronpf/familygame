import 'package:caldero_app/src/art/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// [n] fotogramas a [fps], todos con los mismos tiempos de interfaz y dibujo.
List<FrameSample> frames(int n,
    {double fps = 120,
    double build = 3,
    double raster = 4,
    int slowEvery = 0,
    double slowMs = 20}) {
  final gap = (1e6 / fps).round();
  return [
    for (var i = 0; i < n; i++)
      FrameSample(
        buildMs: build,
        rasterMs: (slowEvery > 0 && i % slowEvery == 0) ? slowMs : raster,
        finishUs: 1000000 + i * gap,
      ),
  ];
}

void main() {
  test('el presupuesto sale de la frecuencia de la pantalla', () {
    expect(summarizeFrames(frames(10), refreshRateHz: 60).budgetMs,
        closeTo(16.67, 0.01));
    expect(summarizeFrames(frames(10), refreshRateHz: 120).budgetMs,
        closeTo(8.33, 0.01));
  });

  test(
      '120 fps con 3 ms de interfaz y 4 de dibujo: dentro del presupuesto de 120 Hz',
      () {
    final m = summarizeFrames(frames(200), refreshRateHz: 120);
    expect(m.fps, closeTo(120, 0.5));
    expect(m.avgBuildMs, 3);
    expect(m.avgRasterMs, 4);
    expect(m.worstMs, 4);
    expect(m.overBudgetPercent, 0);
  });

  test('el mismo fotograma de 12 ms es lento a 120 Hz pero no a 60 Hz', () {
    final s = frames(100, raster: 12);
    expect(summarizeFrames(s, refreshRateHz: 120).overBudgetPercent, 100);
    expect(summarizeFrames(s, refreshRateHz: 60).overBudgetPercent, 0);
  });

  test('cuenta el porcentaje de fotogramas que pierden su turno y el peor', () {
    final m = summarizeFrames(frames(100, slowEvery: 10, slowMs: 25),
        refreshRateHz: 60);
    expect(m.overBudgetPercent, 10);
    expect(m.worstMs, 25);
  });

  test('un fotograma cuenta como lento si lo es la interfaz O el dibujo', () {
    const ui = FrameSample(buildMs: 20, rasterMs: 2, finishUs: 0);
    const gpu = FrameSample(buildMs: 2, rasterMs: 20, finishUs: 1);
    expect(
        summarizeFrames([ui, gpu], refreshRateHz: 60).overBudgetPercent, 100);
  });

  test('sin fotogramas no falla', () {
    final m = summarizeFrames(const [], refreshRateHz: 60);
    expect((m.count, m.fps, m.overBudgetPercent), (0, 0, 0));
  });

  test('el texto muestra los dos tiempos, el presupuesto y la frecuencia', () {
    final m = summarizeFrames(frames(200), refreshRateHz: 120);
    final text = formatSummary(m, refreshRateHz: 120);
    expect(text, contains('120 fps'));
    expect(text, contains('UI 3.0 ms'));
    expect(text, contains('dibujo 4.0 ms'));
    expect(text, contains('sobre 8.3 ms (120 Hz)'));
    expect(formatSummary(m, refreshRateHz: 120, debugNote: '\n⚠ debug'),
        endsWith('⚠ debug'));
  });
}
