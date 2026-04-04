import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Semantic palette (dark-optimised) ─────────────────────────────────────
  static const Color primaryColor = Color(0xFF5B9BFF); // vivid blue
  static const Color accentColor  = Color(0xFF82B1FF); // softer blue
  static const Color warningColor = Color(0xFFFFB300); // amber
  static const Color successColor = Color(0xFF4CAF50); // green
  static const Color errorColor   = Color(0xFFFF5252); // red

  // ── Dark surface palette ──────────────────────────────────────────────────
  static const Color darkBg      = Color(0xFF0D0D14); // deepest background
  static const Color darkSurface = Color(0xFF14141F); // app bar / nav bar
  static const Color darkCard    = Color(0xFF1C1C2B); // card / dialog
  static const Color darkBorder  = Color(0xFF2A2A3D); // subtle borders
  static const Color darkOnBg    = Color(0xFFE8EAF6); // primary text
  static const Color darkOnMuted = Color(0xFF8A8AAD); // secondary/hint text

  // Private aliases used internally
  static const Color _bg      = darkBg;
  static const Color _surface = darkSurface;
  static const Color _card    = darkCard;
  static const Color _border  = darkBorder;
  static const Color _onBg    = darkOnBg;
  static const Color _onMuted = darkOnMuted;

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      primaryColor: primaryColor,
      canvasColor: _surface,
      cardColor: _card,
      dialogTheme: const DialogThemeData(backgroundColor: _card),
      hintColor: _onMuted,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
        surface: _surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _onBg,
        onError: Colors.white,
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _onBg,
        elevation: 0,
        centerTitle: true,
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: primaryColor.withValues(alpha: 0.4),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: warningColor,
          side: const BorderSide(color: warningColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: errorColor,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: _card,
        elevation: 6,
        shadowColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border, width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ── Bottom nav ────────────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: primaryColor,
        unselectedItemColor: _onMuted,
        type: BottomNavigationBarType.fixed,
      ),

      // ── Misc ──────────────────────────────────────────────────────────────
      dividerColor: _border,
      iconTheme: const IconThemeData(color: _onBg),
      listTileTheme: const ListTileThemeData(
        iconColor: _onMuted,
        textColor: _onBg,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryColor : _onMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primaryColor.withValues(alpha: 0.35)
              : _border,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _border,
        labelStyle: const TextStyle(color: _onBg, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: primaryColor),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: _onBg,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleMedium: TextStyle(color: _onBg),
        bodyLarge: TextStyle(color: _onBg),
        bodyMedium: TextStyle(color: _onMuted),
      ),
    );
  }
}
