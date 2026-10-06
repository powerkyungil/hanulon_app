import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/application/auth_controller.dart';

class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    if (_error != null) setState(() => _error = null);

    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .restoreSession();
      if (!mounted) return;
      if (session == null) {
        context.go('/login');
      } else if (session.isDeputy && session.activeCharacter == null) {
        context.go('/deputy/characters');
      } else {
        context.go('/home');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    if (_error != null) {
      return Scaffold(
        body: ErrorView(message: '앱을 시작하지 못했습니다.', onRetry: _bootstrap),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Icon(
                  Icons.groups_rounded,
                  color: scheme.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            const Text('오딘 길드', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space4),
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
