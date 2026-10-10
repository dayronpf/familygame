import 'package:flutter/material.dart';

/// Colores de la app: una noche de cuento (índigo y ámbar), cálida y sin blanco puro, para mirar en la cama sin
/// deslumbrar, pero con color suficiente para que lo entienda un niño.
class Palette {
  Palette._();

  static const Color skyTop = Color(0xFF120F34);
  static const Color skyMid = Color(0xFF241A5A);
  static const Color skyLow = Color(0xFF3A2670);
  static const Color card = Color(0xFF2A2160);
  static const Color cardSoft = Color(0xFF33297A);
  static const Color cream = Color(0xFFF7E9CC);
  static const Color amber = Color(0xFFFFC857);
  static const Color amberDark = Color(0xFF3A2606);
  static const Color teal = Color(0xFF6FE3D0);
  static const Color moon = Color(0xFFFFF1C2);
  static const Color mutedText = Color(0xFFB9B0E0);

  /// Color de cada enseñanza (se reconoce de un vistazo).
  static const Map<String, Color> moral = {
    'honestidad': Color(0xFF5DA9FF),
    'generosidad': Color(0xFFFF8FB1),
    'valentia': Color(0xFFFF9F5A),
  };
  static const Color surprise = Color(0xFFB48CFF);
}
