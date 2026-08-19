import 'package:flutter/material.dart';

import '../../app/theme/app_radii.dart';
import '../../app/theme/app_text_styles.dart';

class StatusTag extends StatelessWidget {
  const StatusTag({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    this.icon,
    super.key,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.tag),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon case final icon?) ...<Widget>[
              Icon(icon, size: 14, color: foregroundColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
