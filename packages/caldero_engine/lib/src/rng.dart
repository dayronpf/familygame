/// Generador pseudoaleatorio determinista (mulberry32).
///
/// No se usa `dart:math` `Random` porque su secuencia no está garantizada
/// entre versiones del SDK; aquí la misma semilla debe dar siempre el mismo
/// cuento (para repetir y compartir cuentos).
class Mulberry32 {
  Mulberry32(int seed) : _state = seed & _mask;

  static const int _mask = 0xFFFFFFFF;

  int _state;

  static int _imul(int a, int b) {
    final ah = (a >> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    return ((al * b) + (((ah * b) & 0xFFFF) << 16)) & _mask;
  }

  /// Siguiente entero sin signo de 32 bits.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ (t + _imul(t ^ (t >> 7), t | 61))) & _mask;
    return (t ^ (t >> 14)) & _mask;
  }

  /// Entero en `[0, max)`.
  int nextInt(int max) {
    if (max <= 0) throw RangeError.value(max, 'max', 'debe ser positivo');
    return (nextUint32() * max) ~/ 0x100000000;
  }

  /// Elemento al azar de una lista no vacía.
  T choice<T>(List<T> items) => items[nextInt(items.length)];
}
