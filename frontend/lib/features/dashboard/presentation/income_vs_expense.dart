import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_trends.dart';

/// « Revenus vs dépenses » — per month, an income bar and an expense bar side by side on a
/// shared zero baseline, with the month and its net beneath (see `docs/design/04-dashboard.md`
/// §Row 3).
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
    // The tallest single bar sets the scale, so income and expense stay comparable between
    // months rather than each pair normalising to itself.
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
          color: context.colors.positive,
          label: l10n.dashboardLegendIncome,
        ),
        const SizedBox(width: AppSpacing.md),
        _LegendDot(
          color: context.colors.negative,
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
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// One month: its income and expense bars side by side, its label, and its net.
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

  /// Column width, gap between the pair's two bars, and the corner radii — all pinned by the
  /// spec. Each bar takes half the column, less half the gap.
  static const barWidth = 44.0;
  static const pairGap = 2.0;
  static const _singleBarWidth = (barWidth - pairGap) / 2;
  static const _barRadius = BorderRadius.vertical(
    top: Radius.circular(6),
    bottom: Radius.circular(2),
  );

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
                  // One scale for both bars and every month: the tallest single figure fills
                  // the plot, so a bar can never exceed the height it is drawn in.
                  final scale = peak == 0 ? 0.0 : constraints.maxHeight / peak;
                  final month = '${totals.month.year}-${totals.month.month}';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Bar(
                        key: Key('dashboardIncomeBar-$month'),
                        height: totals.incomeMinor * scale,
                        color: context.colors.positive,
                      ),
                      const SizedBox(width: pairGap),
                      _Bar(
                        key: Key('dashboardExpenseBar-$month'),
                        height: totals.expenseMinor * scale,
                        color: context.colors.negative,
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
                _MonthLabel(
                  label: monthLabel,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    // The month being looked at is stated in primary; the ones it is
                    // compared against recede.
                    color: isCurrent
                        ? context.colors.text
                        : context.colors.textSecondary,
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

/// The month's name, always on one line at full size, centred under its column and free to
/// spill into the space between columns. A label that wrapped (or shrank to fit) would change
/// its own height and lift that month's bars off the baseline the others stand on, so the
/// zone's height comes from one invisible line in the same style instead of from the label.
class _MonthLabel extends StatelessWidget {
  const _MonthLabel({required this.label, required this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(child: Text(' ', maxLines: 1, style: style)),
        Positioned(
          top: 0,
          left: -MonthBar.barWidth,
          right: -MonthBar.barWidth,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MonthBar._singleBarWidth,
      height: height.isFinite && height > 0 ? height : 0,
      decoration: BoxDecoration(
        color: color,
        borderRadius: MonthBar._barRadius,
      ),
    );
  }
}

/// Hovering a month's pair names its two figures — the bars alone shows proportion, not amount.
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
            ).copyWith(color: context.colors.positive),
          ),
          TextSpan(
            text:
                '${l10n.dashboardLegendExpense}  ${amount(-totals.expenseMinor)}',
            style: tabularNumberStyle(
              Theme.of(context).textTheme.bodySmall!,
            ).copyWith(color: context.colors.negative),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
