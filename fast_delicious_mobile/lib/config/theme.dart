import 'package:flutter/material.dart';

/// Palette reprise à l'identique du frontend web (src/index.css), pour garder
/// la même identité visuelle Fast & Delicious entre le web et le mobile.
class AppColors {
  static const cream = Color(0xFFFBF4E4);
  static const cream2 = Color(0xFFF3E9D2);
  static const ink = Color(0xFF2B241A);
  static const inkSoft = Color(0xFF7A7061);
  static const red = Color(0xFFD6402A);
  static const redDim = Color(0xFFB23320);
  static const green = Color(0xFF3D8A4F);
  static const greenDim = Color(0xFF2E6B3D);
  static const gold = Color(0xFFE8A63B);
  static const panel = Color(0xFFFFFFFF);
  static const line = Color(0xFFE5D8BB);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.red,
        primary: AppColors.red,
        secondary: AppColors.gold,
        surface: AppColors.panel,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      fontFamily: 'Roboto',
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.cream,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
