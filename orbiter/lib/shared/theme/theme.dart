import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get darkTheme => _darkTheme();
  static ThemeData get lightTheme => _lightTheme();

  static ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: OrbiterColors.interactive,
      scaffoldBackgroundColor: OrbiterColors.surfaceDark,
      colorScheme: ColorScheme.dark(
        primary: OrbiterColors.interactive,
        secondary: OrbiterColors.interactive,
        surface: OrbiterColors.surfaceDark,
        error: OrbiterColors.critical,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: OrbiterColors.surfaceDark,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: Color(0xFF1E293B),
        elevation: 2,
      ),
    );
  }
  
  static ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: OrbiterColors.interactive,
      scaffoldBackgroundColor: OrbiterColors.surfaceLight,
      colorScheme: ColorScheme.light(
        primary: OrbiterColors.interactive,
        secondary: OrbiterColors.interactive,
        surface: OrbiterColors.surfaceLight,
        error: OrbiterColors.critical,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: OrbiterColors.surfaceLight,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
      ),
    );
  }
}

// Made with Bob
