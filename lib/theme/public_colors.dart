import 'package:flutter/material.dart';

/// Color palette for the public marketing site (landing page + the
/// About/Services/Rates/Contact pages) — navy/gold, deliberately distinct
/// from AppTheme (the admin/warehouse dashboard's Soft Blush + Lavender
/// palette). Single source of truth so every public-facing screen and
/// lib/widgets/site_chrome.dart agree on the exact same colors; LandingScreen
/// keeps its own same-named static fields as thin aliases to these so its
/// ~100 existing `LandingScreen.xxx` references elsewhere in that file don't
/// need to change.
class PublicColors {
  static const navy = Color(0xFF071B33);
  static const secondaryNavy = Color(0xFF123A68);
  static const yellow = Color(0xFFFFC400);
  static const gold = Color(0xFFD9A514);
  static const white = Color(0xFFFFFFFF);
  static const iceGray = Color(0xFFF5F7FA);
  static const borderGray = Color(0xFFDCE3EA);
  static const charcoal = Color(0xFF263442);
  static const green = Color(0xFF16845B);
  static const red = Color(0xFFB83A3A);
  static const charcoalSoft = Color(0xFF5B6B7A);
}
