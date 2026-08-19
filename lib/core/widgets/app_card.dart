import 'package:flutter/material.dart';

import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_palette.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.space4),
    this.borderColor,
    this.emphasized = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppRadii.card);
    final palette = context.appPalette;
    final color = emphasized ? palette.surfaceElevated : palette.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? palette.cardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: emphasized ? 18 : 8,
            offset: Offset(0, emphasized ? 6 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
