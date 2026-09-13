import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/password_strength.dart';

/// Four segments and a right-aligned verdict, shown under the password field.
///
/// The verdict is spelled out rather than left to the bar's color, so the
/// judgement doesn't rest on hue alone.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (strength) {
      PasswordStrength.empty => (null, AppColors.surfaceHover),
      PasswordStrength.weak => (
        l10n.authPasswordStrengthWeak,
        AppColors.negative,
      ),
      PasswordStrength.fair => (
        l10n.authPasswordStrengthFair,
        AppColors.warning,
      ),
      PasswordStrength.strong || PasswordStrength.excellent => (
        l10n.authPasswordStrengthStrong,
        AppColors.iris,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          for (var segment = 0; segment < 4; segment++) ...[
            if (segment > 0) const SizedBox(width: AppSpacing.xs + 1),
            Expanded(
              child: Container(
                key: Key('passwordStrengthSegment$segment'),
                height: 4,
                decoration: BoxDecoration(
                  color: segment < strength.filledSegments
                      ? color
                      : AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          SizedBox(
            width: 74,
            child: Text(
              label ?? '',
              key: const Key('passwordStrengthVerdict'),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.helper.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
