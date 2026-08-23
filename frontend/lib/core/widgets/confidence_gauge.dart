import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// How sure the model is about a proposal: a 44×5 track with an iris fill, and
/// the « Confiance NN % » caption beside it (`docs/design/00` §Phase 2).
///
/// The bar and the caption ship together because neither is sufficient alone —
/// the bar is comparable at a glance across rows, the caption is the exact
/// figure and the part a screen reader can read. Meaning is never on the bar
/// alone.
class ConfidenceGauge extends StatelessWidget {
  const ConfidenceGauge({super.key, required this.confidence, required this.label});

  /// The model's confidence in `[0,1]` — the raw API value. Formatting it as a
  /// percentage happens where every other number is formatted, in the caller's
  /// localized [label]; this widget only needs the fraction to draw a width.
  final double confidence;

  /// The localized « Confiance NN % » caption.
  final String label;

  @override
  Widget build(BuildContext context) {
    final fraction = confidence.clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: label,
          excludeSemantics: true,
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.iris,
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
