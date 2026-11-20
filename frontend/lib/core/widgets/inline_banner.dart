import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';

/// What an [InlineBanner] or a toast reports. Drives the icon and its colour
/// together, so the message never rests on colour alone.
enum BannerTone {
  error(LucideIcons300.circleX),
  warning(LucideIcons300.triangleAlert),
  info(LucideIcons300.info),
  success(LucideIcons300.circleCheck);

  const BannerTone(this.icon);

  final IconData icon;

  /// The icon's colour. Informational banners are neutral
  /// (`docs/design/00-design-system.md` §2.2).
  Color color(AppColors colors) => switch (this) {
    error => colors.negative,
    warning => colors.warning,
    info => colors.textSecondary,
    success => colors.positive,
  };
}

/// The banner of `docs/design/00-design-system.md` §7, for something the
/// user can act on: `surface`, 1 px `lineStrong`, radius 8, padding 8 12; a
/// leading 14 px icon, 13 px text, [actions] on the right and an optional
/// ghost close. The banner itself stays neutral; only the icon takes the
/// tone's colour. Something to know rather than act on is a `NoteLine`.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required String this.message,
    this.tone = BannerTone.error,
    this.onDismiss,
    this.dismissTooltip,
    this.icon,
    this.actions = const [],
  }) : content = null;

  /// A banner whose body is richer than one sentence (a file name, a status
  /// and a select, say), laid out by the caller between the icon and the
  /// [actions]. Same box, icon and actions as the default banner.
  const InlineBanner.custom({
    super.key,
    required Widget this.content,
    this.tone = BannerTone.info,
    this.onDismiss,
    this.dismissTooltip,
    this.icon,
    this.actions = const [],
  }) : message = null;

  /// The sentence, or `null` for a [InlineBanner.custom] banner.
  final String? message;

  /// The body of a [InlineBanner.custom] banner.
  final Widget? content;

  final BannerTone tone;

  /// Overrides the tone's icon while keeping its colour.
  final IconData? icon;

  /// Adds the ghost close. Set only where the banner reports something the
  /// user may decide to live with; a failure the user still has to fix keeps
  /// no close, since dismissing it would hide why the form won't go through.
  final VoidCallback? onDismiss;

  /// Names the close control for assistive tech. Required by callers that
  /// set [onDismiss]; localized text can't be defaulted here.
  final String? dismissTooltip;

  /// Buttons on the right, 8 px apart.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smPlus,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(color: colors.lineStrong),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? tone.icon,
            size: AppSizes.iconSmall,
            color: tone.color(colors),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child:
                content ??
                Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ),
          for (final action in actions) ...[
            const SizedBox(width: AppSpacing.sm),
            action,
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const Key('inlineBannerDismiss'),
              onPressed: onDismiss,
              iconSize: AppSizes.iconSmall,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(
                width: AppSizes.button,
                height: AppSizes.button,
              ),
              padding: EdgeInsets.zero,
              tooltip: dismissTooltip,
              icon: Icon(LucideIcons300.x, color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
