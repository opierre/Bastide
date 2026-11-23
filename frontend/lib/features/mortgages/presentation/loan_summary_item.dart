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
    this.onLeadBaseline = false,
  });

  final String label;
  final String figure;
  final Key? figureKey;
  final String? caption;
  final Key? captionKey;

  /// The lead figure at 40 px with 4 px gaps; otherwise 20 px with 6 px.
  final bool lead;

  /// Sets a 20 px figure on the baseline of the line's 40 px lead, with the
  /// lead's 4 px gaps, so the line's figures share one baseline and its
  /// captions one top, whatever sits under a neighbour (`12-credits.md` §1).
  /// The line then lays its items out from the top.
  final bool onLeadBaseline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final text = Text(
      figure,
      key: figureKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tabularNumberStyle(
        lead ? textTheme.displayLarge! : textTheme.displaySmall!,
      ).copyWith(color: context.colors.text),
    );
    final aligned = onLeadBaseline && !lead;

    return SummaryItem(
      label: label,
      labelGap: lead || onLeadBaseline ? AppSpacing.xs : AppSpacing.xsPlus,
      caption: caption,
      captionKey: captionKey,
      figure: aligned
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: text),
                const LeadFigureStrut(),
              ],
            )
          : text,
    );
  }
}

/// An invisible, zero-width line of lead figure (40 px). In a
/// baseline-aligned row beside a smaller figure, it gives the row the lead's
/// line height and sets the figure on the lead's baseline, at any text size.
class LeadFigureStrut extends StatelessWidget {
  const LeadFigureStrut({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 0,
      child: Opacity(
        opacity: 0,
        child: Text(
          '0',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: tabularNumberStyle(Theme.of(context).textTheme.displayLarge!),
        ),
      ),
    ),
  );
}
