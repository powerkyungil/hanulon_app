import 'package:flutter/material.dart';

import '../../app/theme/app_radii.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_palette.dart';

enum AppButtonVariant { primary, secondary, text, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isBusy = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isBusy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final callback = isBusy ? null : onPressed;
    final palette = context.appPalette;
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isBusy: isBusy,
      foregroundColor: _foregroundColor(context),
    );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: callback,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        child: child,
      ),
      AppButtonVariant.text => TextButton(onPressed: callback, child: child),
      AppButtonVariant.destructive => FilledButton(
        onPressed: callback,
        style: FilledButton.styleFrom(
          backgroundColor: palette.danger,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: AppTextStyles.bodyStrong,
        ),
        child: child,
      ),
    };

    return SizedBox(width: expand ? double.infinity : null, child: button);
  }

  Color _foregroundColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.destructive => Colors.white,
      AppButtonVariant.secondary || AppButtonVariant.text => scheme.onSurface,
    };
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final bool isBusy;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: foregroundColor,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon case final icon?) ...<Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
  }
}
