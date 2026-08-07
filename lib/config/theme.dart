import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DyKalTheme {
  // Palet Modern Couple - Soft Pastel tapi Premium
  static const primary = Color(0xFFFF6B8A); // Pink DyKal
  static const primaryDark = Color(0xFFE85A7A);
  static const secondary = Color(0xFF7B6CF6); // Lavender
  static const accent = Color(0xFFFFC857); // Warm yellow
  static const background = Color(0xFFFFF8F9); // Warm white, bukan putih kasar
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF1A1C1E);
  static const textGrey = Color(0xFF8E9099);
  static const borderSoft = Color(0xFFF1E8EA);
  static const success = Color(0xFF4ECDC4);
  static const online = Color(0xFF00D68F);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      background: background,
      surface: surface,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: textDark),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textDark),
    ),
    // SEAMLESS APPBAR - Tanpa garis pemisah, nyatu sama background
    appBarTheme: AppBarTheme(
      backgroundColor: background, // Sama dengan scaffold!
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w600, color: textDark,
      ),
      iconTheme: IconThemeData(color: textDark),
    ),
    // BOTTOM NAV SEAMLESS - extendBody true
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0, // HAPUS GARIS SHADOW
      selectedItemColor: primary,
      unselectedItemColor: textGrey,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 11),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderSoft, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),
  );

  // Gradient khas DyKal
  static const dykalGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const loveGradient = LinearGradient(
    colors: [Color(0xFFFF6B8A), Color(0xFFFF8E9E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
