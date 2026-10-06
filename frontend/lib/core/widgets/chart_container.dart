import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_card.dart';

/// The shared shell every chart card builds on: an [AppCard] with a title row and a body slot.
/// Panels supply their own chart drawing (donut, bars, sparkline, …) as [child] — this widget
/// only owns the title/spacing so every chart card reads as one family across the app.
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

  /// The 12.5px secondary line under the title, naming the window the chart covers —
  /// « Mai 2026 · 7 catégories », « 4 derniers mois ».
  final String? subtitle;

  /// Optional header content aligned to the trailing edge (a legend toggle, a header metric).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: child),
        ],
      ),
    );
  }
}
