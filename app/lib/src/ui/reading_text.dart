import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// Cómo se ve el texto de los cuentos según los ajustes de lectura: en MAYÚSCULAS y/o más espaciado (más aire entre
/// letras, palabras y renglones, lo que recomiendan para leer con dislexia). Se usa en el lector, en «Leemos juntos»
/// y en la vista previa.
extension ReadingText on BuildContext {
  /// El texto tal como se lee (en mayúsculas si así lo pidieron).
  String readingText(String text) {
    final s = SettingsScope.maybeOf(this);
    return s != null && s.upperCase ? text.toUpperCase() : text;
  }

  /// El estilo del texto con el espaciado pedido.
  TextStyle readingStyle(TextStyle base) {
    final s = SettingsScope.maybeOf(this);
    if (s == null || !s.spacedText) return base;
    final size = base.fontSize ?? 18;
    return base.copyWith(
      letterSpacing: size * 0.08,
      wordSpacing: size * 0.3,
      height: (base.height ?? 1.4) + 0.3,
    );
  }
}
