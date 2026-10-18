// THEME LOCK: dark — source: explicit user request (futuristic glass 2030)
// Scaffold.backgroundColor = AppTheme.backgroundDark — ALL screens

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF65E6C1);
  static const Color primaryContainer = Color(0x2665E6C1);
  static const Color secondary = Color(0xFFA78BFA);
  static const Color secondaryContainer = Color(0x26A78BFA);
  static const Color accentBlue = Color(0xFF73B8FF);
  static const Color accentPink = Color(0xFFFF8AAE);

  // ── Semantic Colors ───────────────────────────────────────────────────
  static const Color success = Color(0xFF65E6C1);
  static const Color successContainer = Color(0x1A65E6C1);
  static const Color warning = Color(0xFFFFC66D);
  static const Color warningContainer = Color(0x1AFFC66D);
  static const Color errorColor = Color(0xFFFF8298);
  static const Color errorContainer = Color(0x1AFF8298);

  // ── Dark Theme Surfaces ───────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF080D18);
  static const Color surfaceDark = Color(0xFF111A2A);
  static const Color surfaceVariantDark = Color(0xFF1A263B);
  static const Color surfaceElevated = Color(0xFF223149);

  // ── Glass System ──────────────────────────────────────────────────────
  static const Color glassBackground = Color(0x20A9C7EA);
  static const Color glassBorder = Color(0x30C1D9F5);
  static const Color glassBackgroundDeep = Color(0x12A9C7EA);

  // ── Text Colors ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE8EDF5);
  static const Color textSecondary = Color(0xFF9AACC5);
  static const Color textMuted = Color(0xFF64738C);

  // ── Light Theme Surfaces (required getter) ────────────────────────────
  static const Color backgroundLight = Color(0xFFF0F4F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // ── Spacing Scale ─────────────────────────────────────────────────────
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // ── Radius Scale ──────────────────────────────────────────────────────
  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 28.0;
  static const double radiusFull = 100.0;

  // ── Blur Levels ───────────────────────────────────────────────────────
  static const double blurLight = 10.0;
  static const double blurMedium = 20.0;
  static const double blurHeavy = 40.0;

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Color(0xFF001A14),
      primaryContainer: primaryContainer,
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: secondary,
      surface: surfaceDark,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariantDark,
      onSurfaceVariant: textSecondary,
      error: errorColor,
      onError: Colors.white,
      outline: Color(0xFF2A3A52),
      outlineVariant: Color(0xFF1A2A3A),
    ),
    textTheme: GoogleFonts.notoSansTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textMuted,
          letterSpacing: 0.5,
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.notoSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 4,
      shadowColor: const Color(0x4465E6C1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusL),
        side: const BorderSide(color: glassBorder, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceDark,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: const Color(0x5565E6C1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        side: const BorderSide(color: glassBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceDark,
      surfaceTintColor: Colors.transparent,
      elevation: 20,
      showDragHandle: true,
      dragHandleColor: textMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 2,
        shadowColor: const Color(0x4465E6C1),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: glassBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: glassBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: glassBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1A2A3A),
      thickness: 1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFCCF5EE),
      onPrimaryContainer: const Color(0xFF001A14),
      secondary: secondary,
      onSecondary: Colors.white,
      surface: surfaceLight,
      onSurface: const Color(0xFF1A1A2E),
      surfaceContainerHighest: const Color(0xFFF0F4F8),
      onSurfaceVariant: const Color(0xFF4A5568),
      error: errorColor,
      onError: Colors.white,
      outline: const Color(0xFFCCCCCC),
      outlineVariant: const Color(0xFFEEEEEE),
    ),
    textTheme: GoogleFonts.notoSansTextTheme(),
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.notoSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A1A2E),
      ),
    ),
  );

  // ── GEL Formatting ────────────────────────────────────────────────────
  static String formatGel(double amount) {
    if (amount >= 1000) {
      final formatted = amount
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
      return '$formatted ₾';
    }
    return '${amount.toStringAsFixed(0)} ₾';
  }

  static String formatGelDecimal(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$formatted ₾';
  }
}
