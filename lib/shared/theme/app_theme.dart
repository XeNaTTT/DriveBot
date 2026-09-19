import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const base = Color(0xFF07080C);
  const accent = Color(0xFFD8FF3E);

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    surface: const Color(0xFF17191F),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: accent,
      secondary: const Color(0xFFFF5A36),
    ),
    scaffoldBackgroundColor: base,
    textTheme: Typography.whiteMountainView.copyWith(
      titleLarge: const TextStyle(fontWeight: FontWeight.w900),
      titleMedium: const TextStyle(fontWeight: FontWeight.w800),
      bodyLarge: const TextStyle(fontSize: 18),
    ),
  );
}
