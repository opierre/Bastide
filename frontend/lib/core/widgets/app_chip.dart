import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A small tinted pill for taxonomy and status labels: account type, import
/// status, system/custom badges. Material's [Chip] carries touch-sized padding
/// and a delete affordance we never want here, so this is a plain themed
/// container.
///
/// Category labels use [CategoryChip] instead — they carry a pinned hue and a
/// category glyph, and the uncategorized case has its own dashed treatment.
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
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: tint == null
            ? AppColors.surfaceOverlay
            : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: tint == null ? AppColors.border : tint.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          // Flexible so a long localized label ellipsizes inside a narrow
          // column instead of overflowing the pill — French status and type
          // labels run well past their English counterparts.
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
