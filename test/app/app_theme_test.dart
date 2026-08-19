import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/app_colors.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/app/theme/app_theme_palette.dart';

void main() {
  test('Icon Purple은 앱 아이콘의 보라색과 라벤더 surface를 사용한다', () {
    final theme = AppTheme.iconPurple;
    final palette = theme.extension<AppThemePalette>()!;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.colorScheme.primary, AppColors.iconPurplePrimary);
    expect(theme.colorScheme.surface, AppColors.iconPurpleSurface);
    expect(palette.backgroundBottom, AppColors.iconPurpleBackground);
    expect(palette.isDark, isFalse);
  });

  test('Sand Gold는 기존 모래색과 골드 포인트를 사용한다', () {
    final theme = AppTheme.sandGold;
    final palette = theme.extension<AppThemePalette>()!;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.colorScheme.primary, AppColors.sandPrimary);
    expect(theme.colorScheme.surface, AppColors.sandSurface);
    expect(palette.backgroundBottom, AppColors.sandBackground);
    expect(palette.isDark, isFalse);
  });

  test('Dark Blue는 깊은 남색과 블루 포인트를 사용한다', () {
    final theme = AppTheme.darkBlue;
    final palette = theme.extension<AppThemePalette>()!;

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppColors.darkPrimary);
    expect(theme.colorScheme.surface, AppColors.darkSurface);
    expect(palette.backgroundBottom, AppColors.darkBackground);
    expect(palette.isDark, isTrue);
  });
}
