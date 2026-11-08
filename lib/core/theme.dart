import 'package:flutter/material.dart';

const midnight = Color(0xFF101A24);
const panel = Color(0xFF192633);
const panelLight = Color(0xFF243545);
const champagne = Color(0xFFD5B77D);
const ivory = Color(0xFFF5F1E9);
const muted = Color(0xFFA8B5C2);
const mint = Color(0xFF63D2B0);

ThemeData vipTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: champagne,
    brightness: Brightness.dark,
    primary: champagne,
    surface: midnight,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base,
    scaffoldBackgroundColor: midnight,
    appBarTheme: const AppBarTheme(backgroundColor: midnight, foregroundColor: ivory, centerTitle: false),
    dividerColor: const Color(0xFF354554),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: champagne)),
      labelStyle: const TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: champagne,
        foregroundColor: midnight,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: panel,
      indicatorColor: champagne.withValues(alpha: .17),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
    ),
  );
}
