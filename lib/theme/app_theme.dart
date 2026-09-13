import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const kGold       = Color(0xFFFFD700);
  static const kGoldLight  = Color(0xFFFFE566);
  static const kGoldDark   = Color(0xFFB8860B);
  static const kBgBlack    = Color(0xFF0A0A0F);
  static const kBgCard     = Color(0xFF13131A);
  static const kBgSurface  = Color(0xFF1C1C28);
  static const kTextPrimary   = Color(0xFFF5F5F5);
  static const kTextSecondary = Color(0xFF9E9E9E);

  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppTheme.kBgBlack,
      colorScheme: const ColorScheme.dark(
        primary: AppTheme.kGold,
        onPrimary: AppTheme.kBgBlack,
        secondary: AppTheme.kGoldLight,
        surface: AppTheme.kBgCard,
        onSurface: AppTheme.kTextPrimary,
        outline: AppTheme.kGoldDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.kBgBlack,
        foregroundColor: AppTheme.kTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppTheme.kTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppTheme.kTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: AppTheme.kTextPrimary, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: AppTheme.kTextPrimary),
        bodySmall: TextStyle(color: AppTheme.kTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.kBgSurface,
        labelStyle: const TextStyle(color: AppTheme.kTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.kGoldDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.kGoldDark, width: 1), // Removed withOpacity for constant definition
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.kGold, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStateProperty.all(AppTheme.kBgSurface)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.kGold,
          foregroundColor: AppTheme.kBgBlack,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppTheme.kGold),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppTheme.kGold : AppTheme.kTextSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppTheme.kGoldDark : AppTheme.kBgSurface),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppTheme.kGold : AppTheme.kTextSecondary),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A2A3A), thickness: 1),
      cardTheme: CardThemeData(
        color: AppTheme.kBgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.kGoldDark, width: 1), // Removed withOpacity for constant definition
        ),
      ),
    );
  }
}
