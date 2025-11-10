import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryPurple = Color(0xFFE040FB);
  static const Color darkBackground = Color(0xFF0A0E21);
  static const Color cardDark = Color(0xFF1D1F33);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);

  static final LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final LinearGradient secondaryGradient = LinearGradient(
    colors: [primaryPurple, primaryCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryCyan,
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      secondary: primaryPurple,
      background: darkBackground,
      surface: cardDark,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        background: Paint()
          ..shader = primaryGradient.createShader(
            const Rect.fromLTWH(0, 0, 200, 100),
          ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.orbitron(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: textSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: primaryCyan, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 8,
      shadowColor: primaryCyan.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryCyan,
    colorScheme: const ColorScheme.light(
      primary: primaryCyan,
      secondary: primaryPurple,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        foreground: Paint()
          ..shader = primaryGradient.createShader(
            const Rect.fromLTWH(0, 0, 200, 100),
          ),
      ),
    ),
  );
}