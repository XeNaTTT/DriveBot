import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const base = Color(0xFF0A0F14);
  const accent = Color(0xFF57E3FF);

  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: base,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: Color(0xFFFFC857),
      surface: Color(0xFF111820),
    ),
    textTheme: ThemeData.dark().textTheme.copyWith(
          headlineMedium: const TextStyle(fontWeight: FontWeight.w700),
          titleMedium: const TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: const TextStyle(fontSize: 18),
        ),
  );
}
