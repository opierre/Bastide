import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../goals/presentation/goal_card.dart';
import '../domain/dashboard_summary.dart';

/// The dashboard's row 1: one card split by vertical dividers into four columns, in reading
/// order Taux d'épargne · Net · Revenus · Dépenses.
///
/// One strip rather than four cards because the four figures are one reading — how the month
/// went — and four separate plates made the eye treat them as four objects. The savings rate
/// leads, in the wider column, as the encouraging headline (`docs/design/04` §Row 1).
class KpiStrip extends StatelessWidget {
  const KpiStrip({super.key, required this.summary, required this.month});

  final DashboardSummary summary;

  /// The month on display; the trend lines compare against the one before it.
  final DateTime month;

  /// The savings column's share against the others' 100 — the old row's `1.35fr`.
  static const savingsFlex = 135;
  static const figureFlex = 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final previousMonth = DateTime(month.year, month.month - 1);
    final vsPrevious = l10n.dashboardStatVsPreviousMonth(previousMonth);

    return AppCard(
      key: const Key('dashboardKpiStrip'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.cardPadding),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: savingsFlex,
              child: _SavingsColumn(summary: summary),
            ),
            const _Divider(),
            Expanded(
              flex: figureFlex,
              child: _FigureColumn(
                id: 'net',
                label: l10n.dashboardStatNet,
                amountMinor: summary.netMinor,
                currency: summary.currency,
                deltaPct: summary.netDeltaPct,
                caption: vsPrevious,
                // The one colorized figure: a surplus reads green, a shortfall red.
                colorizeAmount: true,
              ),
            ),
            const _Divider(),
            Expanded(
              flex: figureFlex,
              child: _FigureColumn(
                id: 'income',
                label: l10n.dashboardStatIncome,
                amountMinor: summary.incomeMinor,
                currency: summary.currency,
                deltaPct: summary.incomeDeltaPct,
                caption: vsPrevious,
              ),
            ),
            const _Divider(),
            Expanded(
              flex: figureFlex,
              child: _FigureColumn(
                id: 'expense',
                label: l10n.dashboardStatExpense,
                amountMinor: -summary.expenseMinor,
                currency: summary.currency,
                deltaPct: summary.expenseDeltaPct,
                caption: vsPrevious,
                // The one column where a rise is bad news.
                invertTrendColor: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 1px separator between two columns, in the subtle in-card line tone.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 1,
    child: ColoredBox(color: AppColors.borderSubtle),
  );
}

/// The leading column: label, the rate, a bar toward the goal, then the goal state and the
/// month's change in points — « ✓ Objectif 20 % atteint · +1,9 pt ».
class _SavingsColumn extends StatelessWidget {
  const _SavingsColumn({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final goal = formatRatioPct(savingsRateGoal, locale, decimalDigits: 0);
    final reached = summary.savingsGoalReached;
    final delta = summary.savingsRateDeltaPct;
    final captionStyle = textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    );

    return Padding(
      key: const Key('dashboardKpi-savings'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPaddingWide,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.dashboardStatSavingsRate.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Iris rather than the neutral secondary: it marks the column that leads the strip.
            style: AppTextStyles.statLabel.copyWith(color: AppColors.iris),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatRatioPct(summary.savingsRate, locale),
            key: const Key('dashboardSavingsRateValue'),
            maxLines: 1,
            style: tabularNumberStyle(textTheme.displayMedium!),
          ),
          const SizedBox(height: AppSpacing.sm),
          GoalProgressBar(
            key: const Key('dashboardSavingsGoalBar'),
            fraction: summary.savingsGoalProgress,
            height: 6,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            key: const Key('dashboardSavingsGoalLine'),
            children: [
              // The check doubles the « atteint » the text already says, so the goal state
              // never rests on the green alone.
              if (reached) ...[
                const Icon(
                  Icons.check_rounded,
                  key: Key('dashboardSavingsGoalReachedIcon'),
                  size: 13,
                  color: AppColors.positive,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  reached
                      ? l10n.dashboardSavingsGoalReached(goal)
                      : l10n.dashboardSavingsGoalPending(goal),
                  key: const Key('dashboardSavingsGoalText'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: captionStyle.copyWith(
                    color: reached
                        ? AppColors.positive
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              Text(' · ', style: captionStyle),
              Text(
                l10n.dashboardSavingsDeltaPoints(
                  formatSignedMagnitude(delta, locale),
                ),
                key: const Key('dashboardSavingsDelta'),
                style: tabularNumberStyle(
                  captionStyle,
                ).copyWith(color: trendColor(delta)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A money column: label, the large signed amount, then « ↑ 2,1 % vs avril ».
class _FigureColumn extends StatelessWidget {
  const _FigureColumn({
    required this.id,
    required this.label,
    required this.amountMinor,
    required this.currency,
    required this.deltaPct,
    required this.caption,
    this.colorizeAmount = false,
    this.invertTrendColor = false,
  });

  /// Suffix of the column's keys — `dashboardKpi-<id>`, `dashboardKpiTrend-<id>`.
  final String id;
  final String label;
  final int amountMinor;
  final String currency;
  final double deltaPct;
  final String caption;
  final bool colorizeAmount;
  final bool invertTrendColor;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final color = trendColor(deltaPct, invert: invertTrendColor);
    final trendStyle = tabularNumberStyle(textTheme.labelSmall!);

    return Padding(
      key: Key('dashboardKpi-$id'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPaddingWide,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.statLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AmountText(
              amountMinor: amountMinor,
              currency: currency,
              // Always signed, colorized or not: the sign carries the direction.
              showPositiveSign: true,
              colorize: colorizeAmount,
              style: textTheme.displayMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            key: Key('dashboardKpiTrend-$id'),
            children: [
              // The arrow carries direction and the hue carries good/bad news, so a fall in
              // expenses can read green while still pointing down.
              Icon(
                switch (deltaPct) {
                  > 0 => Icons.arrow_upward_rounded,
                  < 0 => Icons.arrow_downward_rounded,
                  _ => Icons.remove_rounded,
                },
                size: 13,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                formatRatioPct(deltaPct.abs() / 100, locale),
                key: Key('dashboardKpiDelta-$id'),
                style: trendStyle.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The hue of a month-over-month movement: green when it is good news, red when it is bad,
/// secondary when flat. [invert] is for a metric where a rise is the bad outcome (expenses).
Color trendColor(double delta, {bool invert = false}) => switch (delta) {
  > 0 => invert ? AppColors.negative : AppColors.positive,
  < 0 => invert ? AppColors.positive : AppColors.negative,
  _ => AppColors.textSecondary,
};

/// U+2212 minus sign, matching [AmountText]'s convention rather than the ASCII hyphen `intl`
/// emits.
const _minusSign = '−';

/// A signed number with one decimal and no unit — « +1,9 », « −0,4 ». The savings delta
/// appends « pt » through its ARB message.
String formatSignedMagnitude(double value, String locale) {
  final magnitude = NumberFormat('0.0', locale).format(value.abs());
  final sign = value > 0
      ? '+'
      : value < 0
      ? _minusSign
      : '';
  return '$sign$magnitude';
}

/// A `0..1` ratio as the locale writes a percentage — « 22,3 % » in French, "22.3%" in English.
String formatRatioPct(double ratio, String locale, {int decimalDigits = 1}) =>
    NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: decimalDigits,
    ).format(ratio);
