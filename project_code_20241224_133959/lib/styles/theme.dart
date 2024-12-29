import 'package:flutter/material.dart';

final theme = ThemeData(
  colorScheme: const ColorScheme(
    primary: Color(0xFF0284C7),
    secondary: Color(0xFF14B8A6),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF0F172A),
    onSecondary: Color(0xFF475569),
    onSurface: Color(0xFF0F172A),
    brightness: Brightness.light,
    error: Color(0xFFEF4444),
    onError: Colors.white,
  ),
  useMaterial3: true,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black87),
    headlineSmall: TextStyle(color: Colors.black),
    // Define other text styles as needed
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      textStyle: const TextStyle(fontSize: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      textStyle: const TextStyle(fontSize: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  // Define other theme properties as needed
);
