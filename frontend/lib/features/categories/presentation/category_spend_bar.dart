import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// The spend-share bar on a parent category row: a fixed track filled in the
/// category's own hue (`docs/design/08-categories-rules.md`, HorizontalBars in
/// `docs/design/00` §Components).
///
/// [fraction] is the category's share of the *month's whole expense total* —
/// the same number the « % » beside the bar prints — rather than its share of
/// the largest row. Scaling to the largest row would fill the panel with long,
/// comparable-looking bars, but the leader's bar would then mean "100 % of the
/// leader", which is not a quantity anybody wants to know: read against the
/// month, a short bar is the honest answer, and the bars still compare to each
/// other because they share a track.
///
/// Purely a restatement of the figures beside it, so it is hidden from
/// semantics — a screen reader gets the percentage and the amount as text, and
/// a second, wordless announcement of the same fact is noise.
class CategorySpendBar extends StatelessWidget {
  const CategorySpendBar({super.key, required this.fraction, required this.color});

  /// `0..1`. Zero draws the empty track, which is itself a statement: this
  /// category cost nothing this month.
  final double fraction;
  final Color color;

  static const width = 220.0;
  static const height = 8.0;

  /// A category with a real but tiny share still gets a visible cap rather than
  /// rounding away to an empty track — « 0,2 % » of a month is not nothing.
  static const _minFillWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final filled = fraction <= 0
        ? 0.0
        : (fraction.clamp(0.0, 1.0) * width).clamp(_minFillWidth, width);

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(AppRadii.xs),
              ),
              child: const SizedBox(width: width, height: height),
            ),
            SizedBox(
              width: filled,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
