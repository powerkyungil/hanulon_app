import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'app_button.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    this.title = '문제가 발생했어요',
    required this.message,
    this.onRetry,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 40, color: scheme.error),
            const SizedBox(height: AppSpacing.space3),
            Text(title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space5),
              AppButton(
                label: '다시 시도',
                variant: AppButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              if (onRetry != null) const SizedBox(height: AppSpacing.space2),
              AppButton(
                label: actionLabel!,
                variant: AppButtonVariant.text,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
