import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What an [InlineBanner] is telling the user. Drives hue and glyph together,
/// so the message never rests on color alone.
enum BannerTone {
  error(AppColors.negative, Icons.error_outline_rounded),
  warning(AppColors.warning, Icons.warning_amber_rounded),
  info(AppColors.info, Icons.info_outline_rounded),
  success(AppColors.positive, Icons.check_circle_outline_rounded);

  const BannerTone(this.color, this.icon);

  final Color color;
  final IconData icon;
}

/// Inline message for a form or a panel section: a tinted plate at 10% with a
/// 30–35% border and a leading glyph.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.error,
  });

  final String message;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tone.color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, size: 15, color: tone.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tone.color),
            ),
          ),
        ],
      ),
    );
  }
}
