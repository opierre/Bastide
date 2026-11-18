import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';

/// What a [StatusText] reports, and its default icon
/// (`docs/design/00-design-system.md` §7).
enum StatusTone {
  /// Success, done: `positive`, `check`.
  positive(LucideIcons300.check),

  /// Worth a look: `warning`, `triangle-alert`. Pass `trending-up` for a price
  /// rise or `clock-alert` for a late charge.
  warning(LucideIcons300.triangleAlert),

  /// Failure: `negative`, `circle-x`.
  negative(LucideIcons300.circleX),

  /// A settled or descriptive state (an account type, « Système »):
  /// `textSecondary`, no icon unless one is given.
  neutral(null);

  const StatusTone(this.icon);

  final IconData? icon;

  Color color(AppColors colors) => switch (this) {
    positive => colors.positive,
    warning => colors.warning,
    negative => colors.negative,
    neutral => colors.textSecondary,
  };
}

/// A status: a 13 px icon and 12 px text in one colour. No pill, no dot
/// badge, and nothing at all for a healthy item: the caller shows no
/// [StatusText] there.
///
/// The icon doubles the colour, so the status never rests on colour alone.
class StatusText extends StatelessWidget {
  const StatusText({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;

  /// Replaces the tone's default icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = tone.color(context.colors);
    final icon = this.icon ?? tone.icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppSizes.iconStatus, color: color),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
