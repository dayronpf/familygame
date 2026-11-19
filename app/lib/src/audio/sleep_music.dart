import 'dart:async';

import 'ambience.dart';

/// Música para dormir al terminar el cuento: el sonido de fondo sigue unos minutos (los que eligió la familia en
/// Ajustes) y se apaga solo con un fundido lento. Con «No», se apaga suave a los pocos segundos de terminar.
class SleepMusic {
  SleepMusic(this.ambience, {this.fade = const Duration(seconds: 45)});

  final Ambience ambience;

  /// Lo que dura el fundido final.
  final Duration fade;

  Timer? _wait;
  Timer? _step;
  bool _running = false;

  /// El cuento terminó: deja sonar el fondo [minutes] minutos (0 = se apaga ya, suave) y luego lo funde.
  void storyFinished(int minutes) {
    cancel();
    _running = true;
    if (minutes <= 0) {
      _fadeOut(const Duration(seconds: 6));
    } else {
      _wait = Timer(Duration(minutes: minutes), () => _fadeOut(fade));
    }
  }

  void _fadeOut(Duration over) {
    const steps = 20;
    var i = 0;
    _step = Timer.periodic(over ~/ steps, (t) {
      i++;
      ambience.setLevel((1 - i / steps).clamp(0.0, 1.0));
      if (i >= steps) {
        t.cancel();
        ambience.stop();
        ambience.setLevel(1);
        _running = false;
      }
    });
  }

  /// Volvieron a reproducir o salieron: se olvida la cuenta atrás y el fondo vuelve a su volumen.
  void cancel() {
    _wait?.cancel();
    _step?.cancel();
    if (_running) ambience.setLevel(1);
    _running = false;
  }
}
