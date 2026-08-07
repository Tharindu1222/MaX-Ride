import 'package:flutter/material.dart';

const Color dInk = Color(0xFF12141A);
const Color dAmber = Color(0xFFFFB020);
const Color dNavy = Color(0xFF1A2332);
const Color dFog = Color(0xFFEEF1F6);

ThemeData buildDriverTheme(TextTheme textTheme) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: dFog,
    colorScheme: ColorScheme.fromSeed(
      seedColor: dNavy,
      primary: dNavy,
      secondary: dAmber,
      brightness: Brightness.light,
    ),
    textTheme: textTheme.apply(bodyColor: dInk, displayColor: dInk),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dNavy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
