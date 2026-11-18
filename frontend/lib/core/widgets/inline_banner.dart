import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What an [InlineBanner] is telling the user. Drives hue and glyph together,
/// so the message never rests on color alone.
enum BannerTone {
  error(Icons.error_outline_rounded),
  warning(Icons.warning_amber_rounded),
  info(Icons.info_outline_rounded),
  success(Icons.check_circle_outline_rounded);

  const BannerTone(this.icon);

  final IconData icon;

  /// The tone's hue in the active theme. Informational banners are neutral
  /// (`docs/design/00-design-system.md` §2.2).
  Color color(AppColors colors) => switch (this) {
    error => colors.negative,
    warning => colors.warning,
    info => colors.textSecondary,
    success => colors.positive,
  };
}

/// Inline message for a form or a panel section: a tinted plate at 10% with a
/// 30–35% border and a leading glyph.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.error,
    this.onDismiss,
    this.dismissTooltip,
    this.icon,
  });

  final String message;
  final BannerTone tone;

  /// Overrides the tone's glyph while keeping its hue. Set where a spec draws a
  /// different pairing — the reset confirmation's red triangle
  /// (`docs/design/09-settings.md` state ⑩), which warns rather than reports.
  final IconData? icon;

  /// Adds the spec's dismiss ×. Set only where the banner reports something the
  /// user may reasonably decide to live with — an over-allocation, say. A
  /// failure the user still has to fix keeps no × , because dismissing it would
  /// hide the reason the form won't go through.
  final VoidCallback? onDismiss;

  /// Names the dismiss control for assistive tech. Required by callers that set
  /// [onDismiss]; localized text can't be defaulted here.
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: tone.color(context.colors).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: tone.color(context.colors).withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? tone.icon, size: 15, color: tone.color(context.colors)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tone.color(context.colors),
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              iconSize: 15,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: dismissTooltip,
              icon: Icon(
                Icons.close_rounded,
                color: tone.color(context.colors),
              ),
            ),
        ],
      ),
    );
  }
}
