import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';

/// A filter another panel narrowed this one to, with the means to lift it:
/// toolbar select geometry with a leading [icon] and a ghost `x` in place of
/// the chevron.
class RemovableFilter extends StatelessWidget {
  const RemovableFilter({
    super.key,
    required this.icon,
    required this.label,
    required this.removeTooltip,
    required this.onRemove,
    this.removeKey,
  });

  final IconData icon;
  final String label;

  /// Tooltip and accessible label of the `x`.
  final String removeTooltip;
  final VoidCallback onRemove;
  final Key? removeKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: AppSizes.toolbarSelect,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm + AppSpacing.xxs,
        end: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: colors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSmall, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.xsPlus),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          IconButton(
            key: removeKey,
            onPressed: onRemove,
            tooltip: removeTooltip,
            iconSize: AppSizes.iconSmall,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: AppSizes.iconSmall + AppSpacing.sm,
              height: AppSizes.iconSmall + AppSpacing.sm,
            ),
            icon: Icon(LucideIcons300.x, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
