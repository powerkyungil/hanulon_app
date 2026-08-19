import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import '../core/widgets/app_background.dart';

class OdinGuildApp extends ConsumerWidget {
  const OdinGuildApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeVariant =
        ref.watch(themeControllerProvider).value ?? AppThemeVariant.iconPurple;
    final theme = switch (themeVariant) {
      AppThemeVariant.iconPurple => AppTheme.iconPurple,
      AppThemeVariant.sandGold => AppTheme.sandGold,
      AppThemeVariant.darkBlue => AppTheme.darkBlue,
    };
    final isDarkTheme = themeVariant == AppThemeVariant.darkBlue;

    return MaterialApp.router(
      title: '오딘 길드',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: AppTheme.darkBlue,
      themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (context, child) =>
          AppBackground(child: child ?? const SizedBox.shrink()),
      routerConfig: router,
    );
  }
}
