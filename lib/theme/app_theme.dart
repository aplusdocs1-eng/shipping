import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // "Soft Blush + Lavender Luxury" — the admin/warehouse dashboard's own
  // palette, deliberately distinct from the public site's navy/gold
  // brand (LandingScreen). Feminine, minimal, editorial: soft black text
  // and CTAs against warm off-white and pastel blush/lavender surfaces,
  // not a saturated color on every element.
  static const Color blushPink = Color(0xFFF6C4D4);
  static const Color paleRose = Color(0xFFF8DCE5);
  static const Color softLavender = Color(0xFFE8DDF8);
  static const Color periwinkleMist = Color(0xFFDDE4FA);
  static const Color warmOffWhite = Color(0xFFFFF9FA);
  static const Color softBlack = Color(0xFF171519);
  static const Color mutedGrayText = Color(0xFF69636D);

  /// The palette's signature header/hero treatment — used on the sidebar
  /// header and the dashboard-identity banner, not spread across every
  /// surface (kept minimal per the "clean, editorial" brief).
  static const heroGradient = LinearGradient(
    begin: Alignment(-0.94, -0.34), // CSS linear-gradient(110deg, ...)
    end: Alignment(0.94, 0.34),
    stops: [0.0, 0.48, 1.0],
    colors: [Color(0xFFFBE1E7), Color(0xFFF7ECF5), Color(0xFFDFE6FA)],
  );

  static const Color primary = softBlack; // CTAs, active nav, strong icons
  static const Color primaryDark = softBlack;
  static const Color secondaryNavy = mutedGrayText; // secondary emphasis
  static const Color gold = blushPink; // primary accent/highlight
  static const Color yellow = softLavender; // secondary accent/highlight
  static const Color accent = periwinkleMist; // tertiary accent
  // Status colors deliberately stay conventional (green/amber/red) rather
  // than drawn from the blush/lavender family — the brief covers
  // branding and surfaces, and diluting "paid" or "overdue" into a pink
  // tone would cost real clarity for no requested benefit.
  static const Color success = Color(0xFF3C9A5F);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFD64550);
  static const Color surface = warmOffWhite;
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = softBlack;
  static const Color textSecondary = mutedGrayText;
  static const Color border = paleRose;
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color sidebarText = mutedGrayText;
  static const Color sidebarActive = softBlack;
  static const Color topBarBg = Color(0xFFFFFFFF);

  // Logo URL for network image
  static const String logoUrl = '';

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: surface,
        secondary: gold,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: topBarBg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
