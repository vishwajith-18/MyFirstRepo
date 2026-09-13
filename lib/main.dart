import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CricApp()));
}

// ─── VISH_CRIC Brand Colors ───────────────────────────────────────────────────
const kGold       = Color(0xFFFFD700);
const kGoldLight  = Color(0xFFFFE566);
const kGoldDark   = Color(0xFFB8860B);
const kBgBlack    = Color(0xFF0A0A0F);
const kBgCard     = Color(0xFF13131A);
const kBgSurface  = Color(0xFF1C1C28);
const kTextPrimary   = Color(0xFFF5F5F5);
const kTextSecondary = Color(0xFF9E9E9E);

class CricApp extends StatelessWidget {
  const CricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISH_CRIC',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      // Global watermark via builder — wraps every screen without touching navigation
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          // Persistent VISH_CRIC watermark — bottom center, non-interactive
          const Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Text(
                'VISH_CRIC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x28FFD700),  // 16% opacity gold
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        ],
      ),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: kBgBlack,
      colorScheme: const ColorScheme.dark(
        primary: kGold,
        onPrimary: kBgBlack,
        secondary: kGoldLight,
        surface: kBgCard,
        onSurface: kTextPrimary,
        outline: kGoldDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgBlack,
        foregroundColor: kTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: kTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: kTextPrimary),
        bodySmall: TextStyle(color: kTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kBgSurface,
        labelStyle: const TextStyle(color: kTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGoldDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kGoldDark.withOpacity(0.4), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGold, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStateProperty.all(kBgSurface)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: kBgBlack,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kGold),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kGold : kTextSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kGoldDark.withOpacity(0.5) : kBgSurface),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kGold : kTextSecondary),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A2A3A), thickness: 1),
      cardTheme: CardTheme(
        color: kBgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kGoldDark.withOpacity(0.25), width: 1),
        ),
      ),
    );
  }
}
