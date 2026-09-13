import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CricApp()));
}



class CricApp extends StatelessWidget {
  const CricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISH_CRIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
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
}
