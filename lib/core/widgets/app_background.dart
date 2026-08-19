import 'package:flutter/material.dart';

import '../../app/theme/app_theme_palette.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: context.appPalette.backgroundGradient,
      ),
      child: child,
    );
  }
}
