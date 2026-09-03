import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import '../core/widgets/app_background.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/push_notifications/application/push_navigation_controller.dart';
import '../features/push_notifications/application/push_notification_service.dart';
import '../features/schedule/application/schedule_controller.dart';

class OdinGuildApp extends ConsumerStatefulWidget {
  const OdinGuildApp({super.key});

  @override
  ConsumerState<OdinGuildApp> createState() => _OdinGuildAppState();
}

class _OdinGuildAppState extends ConsumerState<OdinGuildApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      try {
        await ref.read(pushNotificationServiceProvider).initialize();
      } catch (_) {
        // Push setup is optional at runtime and must not prevent app startup.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.listen(pushNavigationControllerProvider, (previous, payload) {
      if (payload == null) return;
      _openPendingNotification(router);
    });
    ref.listen(authControllerProvider, (previous, next) {
      if (next.value != null) _openPendingNotification(router);
    });
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

  void _openPendingNotification(GoRouter router) {
    final session = ref.read(authControllerProvider).value;
    final payload = ref.read(pushNavigationControllerProvider);
    if (session == null || payload == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(scheduleControllerProvider);
      router.go(payload.scheduleLocation);
      ref.read(pushNavigationControllerProvider.notifier).clear();
    });
  }
}
