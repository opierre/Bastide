import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// One item of a summary line (`docs/design/00-design-system.md` §7): label
/// 12 `textSecondary`, the figure, then an optional caption 12
/// `textTertiary`, bottom-aligned with its neighbours. Shared by the list's
/// summary line and the detail's two lines.
class LoanSummaryItem extends StatelessWidget {
  const LoanSummaryItem({
    super.key,
    required this.label,
    required this.figure,
    this.figureKey,
    this.caption,
    this.captionKey,
    this.lead = false,
  });

  final String label;

  /// The figure, as a string: every figure here is neutral (`00` §2.3).
  final String figure;
  final Key? figureKey;
  final String? caption;
  final Key? captionKey;

  /// The lead figure at 40 px with 4 px gaps; otherwise 20 px with 6 px.
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final gap = lead ? AppSpacing.xs : AppSpacing.xsPlus;
    final caption = this.caption;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.statLabel,
        ),
        SizedBox(height: gap),
        Text(
          figure,
          key: figureKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tabularNumberStyle(
            lead ? textTheme.displayLarge! : textTheme.displaySmall!,
          ).copyWith(color: colors.text),
        ),
        if (caption != null) ...[
          SizedBox(height: gap),
          Text(
            caption,
            key: captionKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tabularNumberStyle(
              textTheme.bodySmall!,
            ).copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// The vertical `line` hairline between two items of a summary line, with
/// the line's 40 px either side.
class LoanSummaryHairline extends StatelessWidget {
  const LoanSummaryHairline({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
    child: SizedBox(width: 1, child: ColoredBox(color: context.colors.line)),
  );
}
