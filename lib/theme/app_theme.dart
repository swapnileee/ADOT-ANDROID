import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Forest Green & Organic Store Theme Palette
  static const Color primaryGreen = Color(0xFF1E4D3B);
  static const Color darkGreen = Color(0xFF133528);
  static const Color lightGreenBg = Color(0xFFE8F3EE);
  static const Color creamBg = Color(0xFFF8F9FA); // Soft Light Neutral background
  static const Color accentGold = Color(0xFFD4A373);
  
  // Cards & Neutrals
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFD97706);

  static ThemeData get themeData {
    final textTheme = GoogleFonts.hindSiliguriTextTheme().apply(
      bodyColor: textDark,
      displayColor: textDark,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamBg,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentGold,
        surface: lightCardBg,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: textDark,
        onSurface: textDark,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.hindSiliguri(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCardBg,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cardBorderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Color(0xFF9CA3AF),
        selectedIconTheme: IconThemeData(size: 24),
        unselectedIconTheme: IconThemeData(size: 22),
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
