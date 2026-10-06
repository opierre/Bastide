import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_trends.dart';

/// « Revenus vs dépenses » — one stacked bar per month, income above expense, with the month
/// and its net beneath (see `docs/design/04-dashboard.md` §Row 3).
class IncomeVsExpenseChart extends StatelessWidget {
  const IncomeVsExpenseChart({super.key, required this.trends});

  final DashboardTrends trends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final series = trends.monthlySeries;
    // The last month in the series is the current one — the series ends at today's month by
    // construction, so "current" is the tail rather than a date comparison.
    final currentMonth = series.isEmpty ? null : series.last.month;
    // The tallest single segment sets the scale, so income and expense stay comparable
    // between months rather than each bar normalising to itself.
    final peak = series.fold<int>(0, (largest, row) {
      final tallest = row.incomeMinor > row.expenseMinor
          ? row.incomeMinor
          : row.expenseMinor;
      return tallest > largest ? tallest : largest;
    });

    return ChartContainer(
      title: l10n.dashboardIncomeVsExpenseTitle,
      subtitle: l10n.dashboardIncomeVsExpenseSubtitle(series.length),
      trailing: const _Legend(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final row in series)
            MonthBar(
              totals: row,
              peak: peak,
              currency: trends.currency,
              isCurrent: row.month == currentMonth,
            ),
        ],
      ),
    );
  }
}

/// The green/red dot key in the card's header.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(
          color: AppColors.positive,
          label: l10n.dashboardLegendIncome,
        ),
        const SizedBox(width: AppSpacing.md),
        _LegendDot(
          color: AppColors.negative,
          label: l10n.dashboardLegendExpense,
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm - 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// One month: the stacked bar, its label, and its net.
class MonthBar extends StatelessWidget {
  const MonthBar({
    super.key,
    required this.totals,
    required this.peak,
    required this.currency,
    required this.isCurrent,
  });

  final MonthlyTotals totals;
  final int peak;
  final String currency;
  final bool isCurrent;

  /// Bar width, gap between the two segments, and the corner radii — all pinned by the spec.
  static const barWidth = 44.0;
  static const segmentGap = 2.0;
  static const outerRadius = Radius.circular(6);
  static const innerRadius = Radius.circular(2);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final monthLabel = _capitalize(
      DateFormat('LLL', locale).format(totals.month),
    );

    return SizedBox(
      width: barWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: _HoverTooltip(
              totals: totals,
              currency: currency,
              monthLabel: monthLabel,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Both segments share one scale, minus the gap between them, so a bar can
                  // never exceed the plot it is drawn in.
                  final usable = constraints.maxHeight - segmentGap;
                  final scale = peak == 0 ? 0.0 : usable / (peak * 2);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _Segment(
                        height: totals.incomeMinor * scale,
                        color: AppColors.positive,
                        radius: const BorderRadius.vertical(
                          top: outerRadius,
                          bottom: innerRadius,
                        ),
                      ),
                      const SizedBox(height: segmentGap),
                      _Segment(
                        height: totals.expenseMinor * scale,
                        color: AppColors.negative,
                        radius: const BorderRadius.vertical(
                          top: innerRadius,
                          bottom: outerRadius,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Sized by its own text rather than to a fixed height: the two lines' metrics depend
          // on the font that actually resolves, and a pinned height clips them when it differs
          // from the one measured against. The bar above takes whatever is left.
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthLabel,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    // The month being looked at is stated in primary; the ones it is compared
                    // against recede.
                    color: isCurrent
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  child: AmountText(
                    amountMinor: totals.netMinor,
                    currency: currency,
                    showPositiveSign: true,
                    style: textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.height,
    required this.color,
    required this.radius,
  });

  final double height;
  final Color color;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height.isFinite && height > 0 ? height : 0,
      decoration: BoxDecoration(color: color, borderRadius: radius),
    );
  }
}

/// Hovering a bar names the month's two figures — the bar alone shows proportion, not amount.
class _HoverTooltip extends StatelessWidget {
  const _HoverTooltip({
    required this.totals,
    required this.currency,
    required this.monthLabel,
    required this.child,
  });

  final MonthlyTotals totals;
  final String currency;
  final String monthLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    String amount(int minor) => formatAmount(
      amountMinor: minor,
      currency: currency,
      locale: locale,
      showPositiveSign: true,
    );

    return Tooltip(
      key: Key(
        'dashboardBarTooltip-${totals.month.year}-${totals.month.month}',
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '$monthLabel\n',
            style: tabularNumberStyle(Theme.of(context).textTheme.labelSmall!),
          ),
          TextSpan(
            text:
                '${l10n.dashboardLegendIncome}  ${amount(totals.incomeMinor)}\n',
            style: tabularNumberStyle(
              Theme.of(context).textTheme.bodySmall!,
            ).copyWith(color: AppColors.positive),
          ),
          TextSpan(
            text:
                '${l10n.dashboardLegendExpense}  ${amount(-totals.expenseMinor)}',
            style: tabularNumberStyle(
              Theme.of(context).textTheme.bodySmall!,
            ).copyWith(color: AppColors.negative),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
