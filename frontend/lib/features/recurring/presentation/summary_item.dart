import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// One item of a summary line (`docs/design/00-design-system.md` §7): label
/// 12 `textSecondary`, the figure, then an optional caption 12
/// `textTertiary`, bottom-aligned with its neighbours. Shared by the list's
/// and the series detail's summary lines.
class SummaryItem extends StatelessWidget {
  const SummaryItem({
    super.key,
    required this.label,
    required this.figure,
    this.caption,
    this.labelGap = AppSpacing.xsPlus,
  });

  final String label;
  final Widget figure;
  final String? caption;

  /// The gap between the label, the figure and the caption: 4 under a lead
  /// figure, 6 under the others.
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    final captionStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: context.colors.textTertiary);
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
        SizedBox(height: labelGap),
        figure,
        if (caption != null && caption.isNotEmpty) ...[
          SizedBox(height: labelGap),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tabularNumberStyle(captionStyle),
          ),
        ],
      ],
    );
  }
}

/// The vertical `line` hairline after a summary line's lead, with the
/// line's 40 px either side.
class SummaryHairline extends StatelessWidget {
  const SummaryHairline({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
    child: SizedBox(width: 1, child: ColoredBox(color: context.colors.line)),
  );
}
