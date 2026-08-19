import 'package:flutter/material.dart';

@immutable
class AppThemePalette extends ThemeExtension<AppThemePalette> {
  const AppThemePalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.cardBorder,
    required this.shadow,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.bossMain,
    required this.bossMainSoft,
    required this.bossInvasion,
    required this.bossInvasionSoft,
    required this.bossCommon,
    required this.bossCommonSoft,
    required this.bossFixed,
    required this.bossFixedSoft,
    required this.isDark,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color cardBorder;
  final Color shadow;
  final Color primarySoft;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color bossMain;
  final Color bossMainSoft;
  final Color bossInvasion;
  final Color bossInvasionSoft;
  final Color bossCommon;
  final Color bossCommonSoft;
  final Color bossFixed;
  final Color bossFixedSoft;
  final bool isDark;

  LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[backgroundTop, backgroundBottom],
    stops: const <double>[0, 0.72],
  );

  LinearGradient heroGradient(Color primary) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? <Color>[surfaceElevated, primary.withValues(alpha: 0.20)]
        : <Color>[surface, primarySoft.withValues(alpha: 0.78)],
  );

  @override
  AppThemePalette copyWith({
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? cardBorder,
    Color? shadow,
    Color? primarySoft,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? bossMain,
    Color? bossMainSoft,
    Color? bossInvasion,
    Color? bossInvasionSoft,
    Color? bossCommon,
    Color? bossCommonSoft,
    Color? bossFixed,
    Color? bossFixedSoft,
    bool? isDark,
  }) {
    return AppThemePalette(
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      cardBorder: cardBorder ?? this.cardBorder,
      shadow: shadow ?? this.shadow,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      bossMain: bossMain ?? this.bossMain,
      bossMainSoft: bossMainSoft ?? this.bossMainSoft,
      bossInvasion: bossInvasion ?? this.bossInvasion,
      bossInvasionSoft: bossInvasionSoft ?? this.bossInvasionSoft,
      bossCommon: bossCommon ?? this.bossCommon,
      bossCommonSoft: bossCommonSoft ?? this.bossCommonSoft,
      bossFixed: bossFixed ?? this.bossFixed,
      bossFixedSoft: bossFixedSoft ?? this.bossFixedSoft,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppThemePalette lerp(AppThemePalette? other, double t) {
    if (other == null) return this;
    return AppThemePalette(
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      bossMain: Color.lerp(bossMain, other.bossMain, t)!,
      bossMainSoft: Color.lerp(bossMainSoft, other.bossMainSoft, t)!,
      bossInvasion: Color.lerp(bossInvasion, other.bossInvasion, t)!,
      bossInvasionSoft: Color.lerp(
        bossInvasionSoft,
        other.bossInvasionSoft,
        t,
      )!,
      bossCommon: Color.lerp(bossCommon, other.bossCommon, t)!,
      bossCommonSoft: Color.lerp(bossCommonSoft, other.bossCommonSoft, t)!,
      bossFixed: Color.lerp(bossFixed, other.bossFixed, t)!,
      bossFixedSoft: Color.lerp(bossFixedSoft, other.bossFixedSoft, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemePalette get appPalette =>
      Theme.of(this).extension<AppThemePalette>()!;
}
