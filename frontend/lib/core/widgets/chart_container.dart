import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'section_heading.dart';

/// A chart's section (`docs/design/00-design-system.md` §1.2, §9): a
/// [SectionHeading] with the legend or a control on its right, then the
/// chart filling the rest. Sections, not cards: there is no box around it.
class ChartContainer extends StatelessWidget {
  const ChartContainer({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// The window the chart covers, as a 12 `textTertiary` caption under the
  /// heading. The copy rules drop chart subtitles (`00` §14); until the panel
  /// tickets remove them, they render quietly here.
  final String? subtitle;

  /// The legend (category labels, required for two series or more) or a
  /// control, on the heading's line.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: title, trailing: trailing),
        if (subtitle case final subtitle?) ...[
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Expanded(child: child),
      ],
    );
  }
}
