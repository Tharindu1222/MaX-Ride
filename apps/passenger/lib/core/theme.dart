import 'package:flutter/material.dart';

const Color maxInk = Color(0xFF0B1F1A);
const Color maxForest = Color(0xFF0F3D2E);
const Color maxLime = Color(0xFFC8F560);
const Color maxSand = Color(0xFFF3EFE6);
const Color maxTeal = Color(0xFF1FA89A);

ThemeData buildMaxRideTheme(TextTheme textTheme) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: maxSand,
    colorScheme: ColorScheme.fromSeed(
      seedColor: maxForest,
      primary: maxForest,
      secondary: maxLime,
      surface: maxSand,
      onPrimary: Colors.white,
      brightness: Brightness.light,
    ),
    textTheme: textTheme.apply(bodyColor: maxInk, displayColor: maxInk),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: maxInk,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: maxForest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
