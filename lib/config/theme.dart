import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DyKalTheme {
  // Palet Soft Pastel & TikTok Soft Dark (Standar Modern 2026)
  static const primary = Color(0xFFFF6B8A);      // Soft Rose Pastel
  static const primaryDark = Color(0xFFFE2C55);  // TikTok Signature Rose
  static const secondary = Color(0xFF7B6CF6);    // Lavender Soft
  static const accent = Color(0xFFFFC857);       // Warm Yellow
  
  // Light Mode Colors
  static const background = Color(0xFFFFF8F9);   // Warm White
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF1A1C1E);
  static const textGrey = Color(0xFF8E9099);
  static const borderSoft = Color(0xFFF1E8EA);
  static const success = Color(0xFF4ECDC4);
  static const online = Color(0xFF00D68F);

  // Soft Dark TikTok Mode Colors (Matte Neutral, No Harsh Neon)
  static const backgroundDark = Color(0xFF121212); // Soft Matte Dark
  static const surfaceDark = Color(0xFF1F2029);    // Elevated Soft Dark
  static const surfaceSubduedDark = Color(0xFF262833);
  static const borderSoftDark = Color(0xFF2D303E);
  static const textMutedDark = Color(0xFF8A8B91);  // TikTok Clean Gray

  static const LinearGradient dykalGradient = LinearGradient(
    colors: [primary, Color(0xFFFF8EAB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient loveGradient = LinearGradient(
    colors: [Color(0xFFFF6B8A), Color(0xFFFF4D79)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: surface,
      onSurface: textDark,
      outline: borderSoft,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: textDark),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textDark),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
      iconTheme: const IconThemeData(color: textDark),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
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
        side: const BorderSide(color: borderSoft, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: primaryDark,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: surfaceDark,
      onSurface: Colors.white,
      outline: borderSoftDark,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
      bodyMedium: GoogleFonts.plusJakartaSans(color: Colors.white),
      bodySmall: GoogleFonts.plusJakartaSans(color: textMutedDark),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      elevation: 0,
      selectedItemColor: primaryDark,
      unselectedItemColor: textMutedDark,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 11),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderSoftDark, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),
  );

  // Dynamic Theme Helpers
  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : card;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderSoftDark : borderSoft;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white : textDark;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textMutedDark : textGrey;
}
