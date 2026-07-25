import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A small tinted pill used for taxonomy labels: account type, category, import
/// status. Material's [Chip] carries touch-sized padding and a delete affordance
/// we never want here, so this is a plain themed container.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.color, this.icon});

  final String label;

  /// Tint hue; defaults to a neutral secondary-text chip.
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = color;
    final foreground = tint ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: tint == null
            ? AppColors.surfaceOverlay
            : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: tint == null ? AppColors.border : tint.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
