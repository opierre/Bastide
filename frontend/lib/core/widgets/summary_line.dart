import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// One item of a summary line (`docs/design/00-design-system.md` §7): label
/// 12 `textSecondary`, the figure, then an optional caption 12
/// `textTertiary` or a trend line, bottom-aligned with its neighbours.
///
/// A panel lays its items out in an `IntrinsicHeight` row stretched to one
/// height, so a [SummaryHairline] between two of them runs the line's full
/// height.
class SummaryItem extends StatelessWidget {
  const SummaryItem({
    super.key,
    required this.label,
    required this.figure,
    this.labelKey,
    this.caption,
    this.captionKey,
    this.captionMaxLines = 1,
    this.below,
    this.labelGap = AppSpacing.xsPlus,
  }) : assert(
         caption == null || below == null,
         'An item carries a caption or a trend line, not both.',
       );

  final String label;
  final Key? labelKey;

  /// The figure, styled by the caller: 40 px for the lead, 28 or 20 px for
  /// the others, signed and coloured per `00` §2.3.
  final Widget figure;

  /// 12 `textTertiary` under the figure; an empty caption is not drawn.
  final String? caption;
  final Key? captionKey;
  final int captionMaxLines;

  /// A trend line or a status in place of the caption.
  final Widget? below;

  /// The gap between the label, the figure and what follows: 4 under a lead
  /// figure, 6 under the others.
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    final below = this.below;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          key: labelKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.statLabel,
        ),
        SizedBox(height: labelGap),
        figure,
        if (caption != null && caption.isNotEmpty) ...[
          SizedBox(height: labelGap),
          Text(
            caption,
            key: captionKey,
            maxLines: captionMaxLines,
            overflow: TextOverflow.ellipsis,
            style: tabularNumberStyle(
              Theme.of(context).textTheme.bodySmall!,
            ).copyWith(color: context.colors.textTertiary),
          ),
        ] else if (below != null) ...[
          SizedBox(height: labelGap),
          below,
        ],
      ],
    );
  }
}

/// The vertical `line` hairline between two items of a summary line, with
/// the line's 40 px either side (`00` §7).
class SummaryHairline extends StatelessWidget {
  const SummaryHairline({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
    child: SizedBox(width: 1, child: ColoredBox(color: context.colors.line)),
  );
}
