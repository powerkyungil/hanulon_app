import 'package:flutter/material.dart';

import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_palette.dart';

class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.space5),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(AppRadii.card + 4);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: palette.heroGradient(primary),
        borderRadius: radius,
        border: Border.all(color: primary.withValues(alpha: 0.26)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
