import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const pageTitle = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.45,
  );

  static const sectionTitle = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const cardTitle = TextStyle(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
  );

  static const bodyStrong = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const countdown = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const textTheme = TextTheme(
    displaySmall: display,
    headlineSmall: pageTitle,
    titleLarge: sectionTitle,
    titleMedium: cardTitle,
    bodyLarge: body,
    bodyMedium: body,
    labelLarge: bodyStrong,
    labelMedium: label,
    bodySmall: caption,
  );
}
