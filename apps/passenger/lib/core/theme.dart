import 'package:flutter/material.dart';

const Color maxInk = Color(0xFF0B1F1A);
const Color maxForest = Color(0xFF0F3D2E);
const Color maxLime = Color(0xFFC8F560);
const Color maxSand = Color(0xFFF6F3EC);
const Color maxTeal = Color(0xFF1FA89A);
const Color maxSurface = Color(0xFFFFFFFF);
const Color maxMuted = Color(0xFF5C6B66);
const Color maxLine = Color(0x1A0B1F1A);
const Color maxPickup = Color(0xFF1B7A4A);
const Color maxDropoff = Color(0xFFC62828);

const List<BoxShadow> maxShadowSoft = [
  BoxShadow(
    color: Color(0x140B1F1A),
    blurRadius: 28,
    offset: Offset(0, 10),
  ),
];

const List<BoxShadow> maxShadowFloat = [
  BoxShadow(
    color: Color(0x1F0B1F1A),
    blurRadius: 20,
    offset: Offset(0, 6),
  ),
];

ThemeData buildMaxRideTheme(TextTheme textTheme) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: maxSand,
    colorScheme: ColorScheme.fromSeed(
      seedColor: maxForest,
      primary: maxForest,
      secondary: maxLime,
      surface: maxSurface,
      onPrimary: Colors.white,
      onSurface: maxInk,
      brightness: Brightness.light,
    ),
    textTheme: textTheme.apply(bodyColor: maxInk, displayColor: maxInk),
    appBarTheme: const AppBarTheme(
      backgroundColor: maxSand,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: maxInk,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: maxInk,
        fontWeight: FontWeight.w800,
        fontSize: 20,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: maxSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: maxInk,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: maxForest,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE4EAE7),
        disabledForegroundColor: maxMuted,
        elevation: 0,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: maxForest,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: Color(0x330F3D2E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: maxForest,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: maxSand,
      hintStyle: const TextStyle(color: maxMuted, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: maxForest, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

String vehicleEmojiFor(String? code) {
  switch (code?.toUpperCase()) {
    case 'TUKTUK':
      return '🛺';
    case 'VAN':
      return '🚐';
    default:
      return '🚗';
  }
}
