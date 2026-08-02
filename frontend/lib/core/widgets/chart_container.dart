import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_card.dart';

/// The shared shell every chart card builds on: an [AppCard] with a title row and a body slot.
/// Panels supply their own chart drawing (donut, bars, sparkline, …) as [child] — this widget
/// only owns the title/spacing so every chart card reads as one family across the app.
class ChartContainer extends StatelessWidget {
  const ChartContainer({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;

  /// Optional header content aligned to the trailing edge (a legend toggle, a header metric).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
