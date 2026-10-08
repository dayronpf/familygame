/// Color ARGB de 32 bits (0xAARRGGBB).
typedef Argb = int;

/// Tinta de los contornos automáticos (no es negro puro: más amable).
const String outlineInk = '#1b1230';

/// Lee `#rrggbb` y devuelve 0xFFRRGGBB.
Argb parseHexColor(String hex) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (h.length != 6) throw FormatException('color inválido: $hex');
  return 0xFF000000 | int.parse(h, radix: 16);
}

/// Mezcla [a] hacia [b] en la proporción [t] (0 = a, 1 = b). Opaco.
Argb mixColors(Argb a, Argb b, double t) {
  int ch(int shift) {
    final ca = (a >> shift) & 0xFF;
    final cb = (b >> shift) & 0xFF;
    return (ca * (1 - t) + cb * t).round().clamp(0, 255);
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// Contorno automático de un relleno: el mismo color oscurecido hacia la tinta.
Argb autoStroke(Argb fill) => mixColors(fill, parseHexColor(outlineInk), 0.62);
