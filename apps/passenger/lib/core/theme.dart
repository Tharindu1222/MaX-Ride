import 'package:flutter/material.dart';

const Color pcWine = Color(0xFF861619);
const Color pcBlack = Color(0xFF0B0B0D);
const Color pcGray = Color(0xFF9A9A9A);
const Color pcWhite = Color(0xFFFFFFFF);

const Color maxInk = pcBlack;
const Color maxForest = pcWine;
const Color maxLime = Color(0xFFC8F560);
const Color maxSand = Color(0xFFF4F4F5);
const Color maxTeal = Color(0xFF1FA89A);
const Color maxSurface = pcWhite;
const Color maxMuted = pcGray;
const Color maxLine = Color(0x1A0B0B0D);
const Color maxPickup = Color(0xFF1B7A4A);
const Color maxDropoff = pcWine;

const List<BoxShadow> maxShadowSoft = [
  BoxShadow(
    color: Color(0x140B0B0D),
    blurRadius: 28,
    offset: Offset(0, 10),
  ),
];

const List<BoxShadow> maxShadowFloat = [
  BoxShadow(
    color: Color(0x1F0B0B0D),
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
      seedColor: pcWine,
      primary: pcWine,
      secondary: pcGray,
      surface: maxSurface,
      onPrimary: pcWhite,
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
      contentTextStyle: const TextStyle(
        color: pcWhite,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: pcWine,
        foregroundColor: pcWhite,
        disabledBackgroundColor: const Color(0xFFE4E4E7),
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
        foregroundColor: pcWine,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: Color(0x33861619)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: pcWine,
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
        borderSide: const BorderSide(color: pcWine, width: 1.4),
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
