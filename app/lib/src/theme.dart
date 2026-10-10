import 'package:flutter/material.dart';

import 'ui/palette.dart';

/// Tema nocturno: índigo profundo con ámbar y texto crema (nunca blanco puro), para leer en la cama sin
/// deslumbrar, con color suficiente para que lo entienda un niño.
ThemeData nightTheme() {
  final textTheme = Typography.material2021().white.apply(
        bodyColor: Palette.cream,
        displayColor: Palette.cream,
      );
  // Todos los botones con la misma letra gruesa que los títulos de las tarjetas (como «Luna»)
  final buttonStyle = ButtonStyle(
    textStyle: WidgetStateProperty.all(
      textTheme.labelLarge!.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.amber,
    brightness: Brightness.dark,
  ).copyWith(
    surface: Palette.skyTop,
    surfaceContainerHighest: Palette.card,
    onSurface: Palette.cream,
    primary: Palette.amber,
    onPrimary: Palette.amberDark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.skyTop,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.skyTop,
      foregroundColor: Palette.cream,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    textTheme: textTheme,
  );
}
