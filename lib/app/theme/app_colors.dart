import 'package:flutter/material.dart';

abstract final class AppColors {
  // Icon Purple
  static const iconPurpleBackgroundTop = Color(0xFFFBFBFC);
  static const iconPurpleBackground = Color(0xFFF4F0F8);
  static const iconPurpleSurface = Color(0xFFFFFFFF);
  static const iconPurpleSurfaceElevated = Color(0xFFFCFAFF);
  static const iconPurpleSurfaceSubtle = Color(0xFFF5F0FA);
  static const iconPurpleText = Color(0xFF241B32);
  static const iconPurpleTextSecondary = Color(0xFF6F637D);
  static const iconPurpleTextTertiary = Color(0xFF968BA2);
  static const iconPurpleOutline = Color(0xFFDCCFE8);
  static const iconPurplePrimary = Color(0xFF8F4AE8);
  static const iconPurplePrimarySoft = Color(0xFFEAD9FB);
  static const iconPurpleAccent = Color(0xFF6B2EA6);
  static const iconPurpleAccentSoft = Color(0xFFEFE2FA);

  // Sand Gold
  static const sandBackgroundTop = Color(0xFFFBF8F1);
  static const sandBackground = Color(0xFFE9E3D7);
  static const sandSurface = Color(0xFFFFFDF8);
  static const sandSurfaceElevated = Color(0xFFF8F2E8);
  static const sandSurfaceSubtle = Color(0xFFF1EADF);
  static const sandText = Color(0xFF211D18);
  static const sandTextSecondary = Color(0xFF70685C);
  static const sandTextTertiary = Color(0xFF948A7A);
  static const sandOutline = Color(0xFFD6CDBD);
  static const sandPrimary = Color(0xFFD9A400);
  static const sandPrimarySoft = Color(0xFFF8E9AF);
  static const sandAccent = Color(0xFFC9542B);
  static const sandAccentSoft = Color(0xFFF6DDD2);

  // Dark Blue
  static const darkBackgroundTop = Color(0xFF111A35);
  static const darkBackground = Color(0xFF080D1B);
  static const darkSurface = Color(0xFF111A31);
  static const darkSurfaceElevated = Color(0xFF182440);
  static const darkSurfaceSubtle = Color(0xFF1B2845);
  static const darkText = Color(0xFFF2F5FC);
  static const darkTextSecondary = Color(0xFFA7B4CC);
  static const darkTextTertiary = Color(0xFF7F8DAA);
  static const darkOutline = Color(0xFF2C3957);
  static const darkPrimary = Color(0xFF6A9DFF);
  static const darkPrimarySoft = Color(0xFF1A315C);
  static const darkAccent = Color(0xFFFF8064);
  static const darkAccentSoft = Color(0xFF4C2728);

  // Shared semantic base values. Theme-specific values live in AppThemePalette.
  static const success = Color(0xFF2FA66B);
  static const successSoft = Color(0xFFE6F5EC);
  static const warning = Color(0xFFE09B14);
  static const warningSoft = Color(0xFFFFEEC9);
  static const danger = Color(0xFFC84848);
  static const dangerSoft = Color(0xFFF9DEDD);

  static const bossMain = Color(0xFF4879D8);
  static const bossMainSoft = Color(0xFFE4ECFF);
  static const bossInvasion = Color(0xFFC9542B);
  static const bossInvasionSoft = Color(0xFFF6DDD2);
  static const bossCommon = Color(0xFF2D8A61);
  static const bossCommonSoft = Color(0xFFDDF2E7);
  static const bossFixed = Color(0xFF7A61C8);
  static const bossFixedSoft = Color(0xFFECE6FA);

  // Compatibility aliases. New UI code should use Theme.of(context) or appPalette.
  static const background = sandBackground;
  static const surface = sandSurface;
  static const surfaceSubtle = sandSurfaceSubtle;
  static const textPrimary = sandText;
  static const textSecondary = sandTextSecondary;
  static const textTertiary = sandTextTertiary;
  static const divider = sandOutline;
  static const primary = sandPrimary;
  static const primarySoft = sandPrimarySoft;
}
