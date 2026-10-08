import 'package:flutter/material.dart';

/// Tema nocturno: fondo casi negro cálido y texto crema (nunca blanco puro),
/// para leer en la cama sin deslumbrar.
ThemeData nightTheme() {
  const background = Color(0xFF14110F);
  const surface = Color(0xFF1F1A17);
  const cream = Color(0xFFF2E3C6);
  const amber = Color(0xFFE8B86D);

  final scheme = ColorScheme.fromSeed(
    seedColor: amber,
    brightness: Brightness.dark,
  ).copyWith(
    surface: background,
    surfaceContainerHighest: surface,
    onSurface: cream,
    primary: amber,
    onPrimary: const Color(0xFF2A1D08),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: cream,
      elevation: 0,
    ),
    textTheme: Typography.material2021().white.apply(
          bodyColor: cream,
          displayColor: cream,
        ),
  );
}
