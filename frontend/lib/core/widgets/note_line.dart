import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';

/// A note: something to know, not to act on
/// (`docs/design/00-design-system.md` §7). A 14 px `textTertiary` icon and
/// 12 `textSecondary` text, no box. Something the user can act on is an
/// [InlineBanner] instead.
class NoteLine extends StatelessWidget {
  const NoteLine({
    super.key,
    required this.text,
    this.icon = LucideIcons300.info,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          // Centres the icon on the first line of 12 px text.
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Icon(
            icon,
            size: AppSizes.iconSmall,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.xsPlus),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
