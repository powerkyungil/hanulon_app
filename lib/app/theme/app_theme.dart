import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_text_styles.dart';
import 'app_theme_palette.dart';

abstract final class AppTheme {
  static const _iconPurpleScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.iconPurplePrimary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.iconPurplePrimarySoft,
    onPrimaryContainer: Color(0xFF3D1764),
    secondary: AppColors.iconPurpleAccent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.iconPurpleAccentSoft,
    onSecondaryContainer: Color(0xFF3D1764),
    tertiary: Color(0xFF3D846A),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFDDF1E8),
    onTertiaryContainer: Color(0xFF1A4D38),
    error: Color(0xFFB23B51),
    onError: Colors.white,
    errorContainer: Color(0xFFF9DFE5),
    onErrorContainer: Color(0xFF7A2034),
    surface: AppColors.iconPurpleSurface,
    onSurface: AppColors.iconPurpleText,
    surfaceContainerHighest: AppColors.iconPurpleSurfaceSubtle,
    onSurfaceVariant: AppColors.iconPurpleTextSecondary,
    outline: AppColors.iconPurpleOutline,
    outlineVariant: Color(0xFFE9DFF0),
    shadow: Color(0x14241B32),
    scrim: Color(0x66241B32),
    inverseSurface: AppColors.iconPurpleText,
    onInverseSurface: AppColors.iconPurpleSurface,
    inversePrimary: Color(0xFFD8B4FF),
  );

  static const _sandScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.sandPrimary,
    onPrimary: AppColors.sandText,
    primaryContainer: AppColors.sandPrimarySoft,
    onPrimaryContainer: AppColors.sandText,
    secondary: AppColors.sandAccent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.sandAccentSoft,
    onSecondaryContainer: Color(0xFF6B2814),
    tertiary: Color(0xFF3F7D50),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFDDEEDD),
    onTertiaryContainer: Color(0xFF245332),
    error: Color(0xFFA43B32),
    onError: Colors.white,
    errorContainer: Color(0xFFF6DEDA),
    onErrorContainer: Color(0xFF76251F),
    surface: AppColors.sandSurface,
    onSurface: AppColors.sandText,
    surfaceContainerHighest: AppColors.sandSurfaceSubtle,
    onSurfaceVariant: AppColors.sandTextSecondary,
    outline: AppColors.sandOutline,
    outlineVariant: Color(0xFFE4DCCF),
    shadow: Color(0x29231C14),
    scrim: Color(0x70211D18),
    inverseSurface: AppColors.sandText,
    onInverseSurface: AppColors.sandSurface,
    inversePrimary: Color(0xFFF2C94C),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkPrimary,
    onPrimary: Color(0xFF07142A),
    primaryContainer: AppColors.darkPrimarySoft,
    onPrimaryContainer: Color(0xFFDDE8FF),
    secondary: AppColors.darkAccent,
    onSecondary: Color(0xFF2E0A05),
    secondaryContainer: AppColors.darkAccentSoft,
    onSecondaryContainer: Color(0xFFFFDAD1),
    tertiary: Color(0xFF37C88A),
    onTertiary: Color(0xFF062317),
    tertiaryContainer: Color(0xFF153C30),
    onTertiaryContainer: Color(0xFFB8F3D9),
    error: Color(0xFFFF6B70),
    onError: Color(0xFF3A070A),
    errorContainer: Color(0xFF4B2027),
    onErrorContainer: Color(0xFFFFDADB),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkText,
    surfaceContainerHighest: AppColors.darkSurfaceSubtle,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkOutline,
    outlineVariant: Color(0xFF202D49),
    shadow: Color(0xB3000000),
    scrim: Color(0xB3000000),
    inverseSurface: AppColors.darkText,
    onInverseSurface: AppColors.darkBackground,
    inversePrimary: Color(0xFF315EA8),
  );

  static const _iconPurplePalette = AppThemePalette(
    backgroundTop: AppColors.iconPurpleBackgroundTop,
    backgroundBottom: AppColors.iconPurpleBackground,
    surface: AppColors.iconPurpleSurface,
    surfaceElevated: AppColors.iconPurpleSurfaceElevated,
    surfaceSubtle: AppColors.iconPurpleSurfaceSubtle,
    cardBorder: Color(0xBFDCCFE8),
    shadow: Color(0x14241B32),
    primarySoft: AppColors.iconPurplePrimarySoft,
    accent: AppColors.iconPurpleAccent,
    accentSoft: AppColors.iconPurpleAccentSoft,
    success: Color(0xFF2F8B62),
    successSoft: Color(0xFFDFF2E8),
    warning: Color(0xFFB76A00),
    warningSoft: Color(0xFFFFEFD1),
    danger: Color(0xFFB23B51),
    dangerSoft: Color(0xFFF9DFE5),
    bossMain: Color(0xFF6357C7),
    bossMainSoft: Color(0xFFEAE8FB),
    bossInvasion: Color(0xFFC26643),
    bossInvasionSoft: Color(0xFFF8E4DB),
    bossCommon: Color(0xFF2F8B62),
    bossCommonSoft: Color(0xFFDFF2E8),
    bossFixed: Color(0xFF7651B6),
    bossFixedSoft: Color(0xFFEEE5F8),
    isDark: false,
  );

  static const _sandPalette = AppThemePalette(
    backgroundTop: AppColors.sandBackgroundTop,
    backgroundBottom: AppColors.sandBackground,
    surface: AppColors.sandSurface,
    surfaceElevated: AppColors.sandSurfaceElevated,
    surfaceSubtle: AppColors.sandSurfaceSubtle,
    cardBorder: Color(0xBFD6CDBD),
    shadow: Color(0x123A2C1D),
    primarySoft: AppColors.sandPrimarySoft,
    accent: AppColors.sandAccent,
    accentSoft: AppColors.sandAccentSoft,
    success: Color(0xFF3F7D50),
    successSoft: Color(0xFFDDEEDD),
    warning: Color(0xFFB87900),
    warningSoft: Color(0xFFFFEDC2),
    danger: Color(0xFFA43B32),
    dangerSoft: Color(0xFFF6DEDA),
    bossMain: Color(0xFF3568B8),
    bossMainSoft: Color(0xFFDCE8F8),
    bossInvasion: AppColors.sandAccent,
    bossInvasionSoft: AppColors.sandAccentSoft,
    bossCommon: Color(0xFF3F7D50),
    bossCommonSoft: Color(0xFFDDEEDD),
    bossFixed: Color(0xFF7058A8),
    bossFixedSoft: Color(0xFFE9E1F4),
    isDark: false,
  );

  static const _darkPalette = AppThemePalette(
    backgroundTop: AppColors.darkBackgroundTop,
    backgroundBottom: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceElevated: AppColors.darkSurfaceElevated,
    surfaceSubtle: AppColors.darkSurfaceSubtle,
    cardBorder: Color(0xFF293755),
    shadow: Color(0x52000000),
    primarySoft: AppColors.darkPrimarySoft,
    accent: AppColors.darkAccent,
    accentSoft: AppColors.darkAccentSoft,
    success: Color(0xFF43D399),
    successSoft: Color(0xFF153C30),
    warning: Color(0xFFF4C453),
    warningSoft: Color(0xFF48391E),
    danger: Color(0xFFFF7378),
    dangerSoft: Color(0xFF4B2027),
    bossMain: Color(0xFF83ADFF),
    bossMainSoft: Color(0xFF1A315C),
    bossInvasion: Color(0xFFFF9177),
    bossInvasionSoft: Color(0xFF4C2728),
    bossCommon: Color(0xFF52D39E),
    bossCommonSoft: Color(0xFF153C30),
    bossFixed: Color(0xFFB7A1FF),
    bossFixedSoft: Color(0xFF302852),
    isDark: true,
  );

  static ThemeData get iconPurple =>
      _build(_iconPurpleScheme, _iconPurplePalette);

  static ThemeData get sandGold => _build(_sandScheme, _sandPalette);

  static ThemeData get darkBlue => _build(_darkScheme, _darkPalette);

  static ThemeData get light => iconPurple;

  static ThemeData _build(ColorScheme scheme, AppThemePalette palette) {
    final textTheme = AppTextStyles.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final borderRadius = BorderRadius.circular(AppRadii.control);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: palette.backgroundBottom,
      textTheme: textTheme,
      fontFamilyFallback: const <String>['Pretendard', 'Noto Sans KR'],
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.pageTitle.copyWith(
          color: scheme.onSurface,
          fontSize: 22,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(48, 52)),
          elevation: const WidgetStatePropertyAll<double>(0),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            AppTextStyles.bodyStrong,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.onSurface,
          backgroundColor: palette.surfaceSubtle.withValues(alpha: 0.46),
          side: BorderSide(color: palette.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: AppTextStyles.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        hintStyle: AppTextStyles.body.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        errorStyle: AppTextStyles.caption.copyWith(color: scheme.error),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface.withValues(
          alpha: palette.isDark ? 0.60 : 0.50,
        ),
        indicatorColor: palette.primarySoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppTextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: palette.cardBorder,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceSubtle,
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: AppTextStyles.label.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.primarySoft
                : palette.surface.withValues(alpha: 0.72);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: palette.cardBorder),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            AppTextStyles.label,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceElevated,
        modalBackgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: palette.cardBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.sandText,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.cardBorder),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
