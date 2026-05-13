import 'package:flutter/material.dart';

class AppTheme {
  // ── ELDER PALETTE ─────────────────────────────────────────────
  static const Color elderPrimary       = Color(0xFFA0522D);
  static const Color elderBackground    = Color(0xFFFFF8F0);
  static const Color elderSurface       = Color(0xFFFFFFFF);
  static const Color elderEmergency     = Color(0xFFD90429);
  static const Color elderTextPrimary   = Color(0xFF1A1A2E);
  static const Color elderTextSecondary = Color(0xFF4A4A6A);

  // Legacy aliases — keep so existing references compile unchanged
  static const Color primaryColor    = elderPrimary;
  static const Color backgroundColor = elderBackground;
  static const Color emergencyColor  = elderEmergency;
  static const Color textPrimary     = elderTextPrimary;
  static const Color textSecondary   = elderTextSecondary;

  // ── COMPANION PALETTE ─────────────────────────────────────────
  static const Color companionPrimary       = Color(0xFF8B5A2B);
  static const Color companionBackground    = Color(0xFFF5F7FA);
  static const Color companionSurface       = Color(0xFFFFFFFF);
  static const Color companionError         = Color(0xFFBA1A1A);
  static const Color companionTextPrimary   = Color(0xFF1C1B1F);
  static const Color companionTextSecondary = Color(0xFF49454F);

  // ── ELDER FONT SIZES (WCAG — do not go below these) ──────────
  static const double fontHuge   = 40.0;
  static const double fontLarge  = 32.0;
  static const double fontMedium = 24.0;
  static const double fontButton = 20.0;

  // ── COMPANION FONT SIZES ──────────────────────────────────────
  static const double companionFontTitle = 22.0;
  static const double companionFontBody  = 16.0;
  static const double companionFontLabel = 14.0;

  // ── RESPONSIVE HELPERS ────────────────────────────────────────
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static double screenPadding(BuildContext context) =>
      isTablet(context) ? 48.0 : 24.0;

  /// Centers content on wide screens; unconstrained on phones.
  static double contentMaxWidth(BuildContext context) =>
      isTablet(context) ? 560.0 : double.infinity;

  static double micButtonSize(BuildContext context) =>
      isTablet(context) ? 260.0 : 200.0;

  static double micIconSize(BuildContext context) =>
      isTablet(context) ? 130.0 : 100.0;

  // ── ELDER THEME ───────────────────────────────────────────────
  static ThemeData get elderTheme {
    return ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: elderBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: elderPrimary,
        primary: elderPrimary,
        error: elderEmergency,
        surface: elderSurface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: elderPrimary, size: 40),
      ),
      iconTheme: const IconThemeData(color: elderPrimary, size: 48),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: elderPrimary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0x4DA0522D),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          minimumSize: const Size(double.infinity, 88),
          textStyle: const TextStyle(
            fontSize: fontButton,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: elderTextSecondary,
          textStyle: const TextStyle(
            fontSize: fontButton,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  // ── COMPANION THEME (Material 3) ──────────────────────────────
  static ThemeData get companionTheme {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: companionPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: companionBackground,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: companionBackground,
      ),
      cardTheme: const CardTheme(
        elevation: 0,
        shape: shape,
        color: companionSurface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF0F0F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFD0D0D0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: companionPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: companionError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: companionError, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(fontSize: companionFontBody),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: shape,
          minimumSize: const Size(double.infinity, 52),
          textStyle: const TextStyle(
            fontSize: companionFontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          minimumSize: const Size(double.infinity, 52),
          textStyle: const TextStyle(
            fontSize: companionFontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          minimumSize: const Size(double.infinity, 52),
          textStyle: const TextStyle(
            fontSize: companionFontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Used by main.dart — maps to elderTheme for backward compatibility.
  static ThemeData get lightTheme => elderTheme;
}
