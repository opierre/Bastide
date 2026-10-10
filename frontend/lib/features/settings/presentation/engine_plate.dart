import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// One way to get an engine, as an inset plate inside the « IA locale » card:
/// tile, label and caption, an action on the right, and an optional line under
/// them (a download's progress bar).
///
/// The same plate as the backup card's export row (`09-settings.md`
/// §Sauvegarde ②), so a second kind of "do this one thing" row in the Données
/// tab reads the way the first one already does.
class EnginePlate extends StatelessWidget {
  const EnginePlate({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    this.captionKey,
    this.captionColor = AppColors.textSecondary,
    this.trailing,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Key? captionKey;

  /// Secondary by default; a failure caption takes the negative hue, always
  /// next to words that say what failed.
  final Color captionColor;

  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.inset),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.irisSoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(icon, size: 18, color: AppColors.iris),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      key: captionKey,
                      style: AppTextStyles.helper.copyWith(color: captionColor),
                    ),
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                trailing,
              ],
            ],
          ),
          if (footer case final footer?) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            footer,
          ],
        ],
      ),
    );
  }
}
