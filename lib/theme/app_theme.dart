import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // One Village Shipping & Freight brand colors. These values are meant
  // to be numerically identical to their counterparts in LandingScreen
  // (lib/screens/landing_screen.dart) — the public marketing site is the
  // reference for the brand; this file exists so ~900 usage sites across
  // the admin dashboard don't have to hardcode it themselves. If you
  // change one, change the other, or the two will drift apart again.
  static const Color primary = Color(0xFF071B33); // = LandingScreen.navy
  static const Color primaryDark = Color(0xFF04101F);
  static const Color secondaryNavy = Color(0xFF123A68); // = LandingScreen.secondaryNavy
  static const Color gold = Color(0xFFD9A514); // = LandingScreen.gold
  static const Color yellow = Color(0xFFFFC400); // = LandingScreen.yellow (the landing page's CTA color)
  // Was sky blue (0xFF0EA5E9) — didn't exist anywhere in the landing
  // page's palette. Reusing secondaryNavy keeps the "second color" this
  // was providing (distinguishing things like Air vs Sea freight badges)
  // while staying inside the brand's own navy family instead of an
  // unrelated hue.
  static const Color accent = Color(0xFF123A68);
  static const Color success = Color(0xFF16845B); // = LandingScreen.green
  // No direct landing-page equivalent — kept as its own warm amber,
  // deliberately close to but distinguishable from `gold`.
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFB83A3A); // = LandingScreen.red
  static const Color surface = Color(0xFFF5F7FA); // = LandingScreen.iceGray
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF263442); // = LandingScreen.charcoal
  static const Color textSecondary = Color(0xFF5B6B7A); // = LandingScreen.charcoalSoft
  static const Color border = Color(0xFFDCE3EA); // = LandingScreen.borderGray
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color sidebarText = Color(0xFF5B6B7A);
  static const Color sidebarActive = Color(0xFF071B33);
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
