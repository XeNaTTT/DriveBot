import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const base = Color(0xFF0A0F14);
  const accent = Color(0xFF57E3FF);

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    surface: const Color(0xFF111820),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(primary: accent, secondary: const Color(0xFFFFC857)),
    scaffoldBackgroundColor: base,
    textTheme: Typography.whiteMountainView.copyWith(
      titleLarge: const TextStyle(fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontSize: 18),
    ),
  );
}
