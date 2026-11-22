import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/summary_line.dart';

/// A [SummaryItem] whose figure is a neutral string (`00` §2.3): every
/// figure of the Crédits summary lines is. Shared by the list's summary line
/// and the detail's two lines.
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
  final String figure;
  final Key? figureKey;
  final String? caption;
  final Key? captionKey;

  /// The lead figure at 40 px with 4 px gaps; otherwise 20 px with 6 px.
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SummaryItem(
      label: label,
      labelGap: lead ? AppSpacing.xs : AppSpacing.xsPlus,
      caption: caption,
      captionKey: captionKey,
      figure: Text(
        figure,
        key: figureKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tabularNumberStyle(
          lead ? textTheme.displayLarge! : textTheme.displaySmall!,
        ).copyWith(color: context.colors.text),
      ),
    );
  }
}
