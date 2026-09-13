import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// The red plate a Données card shows when an action it offers was refused:
/// a bold lead naming what did not happen, then the reason
/// (`docs/design/09-settings.md` states ⑨ and ⑪).
///
/// Not an `InlineBanner`: the banner sets one weight and one color for the whole
/// message, and this one is drawn in two — the lead in red bold, the reason in
/// the body tone.
class RefusalBanner extends StatelessWidget {
  const RefusalBanner({super.key, required this.lead, required this.message});

  /// The bold red opener — « Restauration impossible. »
  final String lead;

  /// What went wrong, and what the user can do about it.
  final String message;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.negative.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.negative.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppColors.negative,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: lead,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.negative,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(text: message),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
