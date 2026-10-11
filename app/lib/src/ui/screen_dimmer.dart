import 'package:screen_brightness/screen_brightness.dart';

/// Baja el brillo de la pantalla poco a poco (el fundido del temporizador de sueño) y lo devuelve al salir.
abstract class ScreenDimmer {
  /// [level] va de 1 (el brillo de siempre) a 0 (lo más oscuro).
  Future<void> setLevel(double level);

  /// Devuelve el brillo que tenía el sistema.
  Future<void> restore();
}

/// No toca el brillo (pruebas, o plataformas sin permiso).
class NoDimmer implements ScreenDimmer {
  const NoDimmer();

  @override
  Future<void> setLevel(double level) async {}

  @override
  Future<void> restore() async {}
}

/// Brillo de **esta app** (no cambia el del sistema ni pide permisos): se vuelve a dejar como estaba al salir.
class SystemDimmer implements ScreenDimmer {
  SystemDimmer({this.minimum = 0.02});

  final double minimum;
  double? _start;
  bool _changed = false;

  @override
  Future<void> setLevel(double level) async {
    try {
      final b = ScreenBrightness.instance;
      _start ??= await b.application;
      final target = (_start! * level.clamp(0.0, 1.0)).clamp(minimum, 1.0);
      _changed = true;
      await b.setApplicationScreenBrightness(target);
    } catch (_) {
      // sin plugin (pruebas) o sin permiso: no pasa nada
    }
  }

  @override
  Future<void> restore() async {
    if (!_changed) return;
    _changed = false;
    _start = null;
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }
}
