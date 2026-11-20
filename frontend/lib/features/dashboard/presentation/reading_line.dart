import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_summary.dart';

/// The dashboard's reading line (`docs/design/04-dashboard.md` §1), the panel's
/// summary line (`00` §7): the savings rate leads at 40 px with its repère,
/// then Revenus, Dépenses and Net at 28 px, separated by vertical hairlines and
/// bottom-aligned.
///
/// A month without data keeps the four labels and shows « — » in
/// `textTertiary` where the figures would be.
class ReadingLine extends StatelessWidget {
  const ReadingLine({super.key, required this.summary, required this.month});

  final DashboardSummary summary;

  /// The month on display; the trends compare it with the one before.
  final DateTime month;

  /// The lead item's width (`04` §1).
  static const leadWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final previous = DateTime(month.year, month.month - 1);
    final hasData = !summary.isEmpty;

    Widget figure({
      required String id,
      required String label,
      required int amountMinor,
      required double deltaPct,
      bool colorize = false,
      bool riseIsBad = false,
    }) => _FigureItem(
      key: Key('dashboardReading-$id'),
      id: id,
      label: label,
      amountMinor: hasData ? amountMinor : null,
      currency: summary.currency,
      colorize: colorize,
      trend: hasData
          ? _Trend(
              id: id,
              deltaPct: deltaPct,
              riseIsBad: riseIsBad,
              caption: l10n.dashboardStatVsPreviousMonth(previous),
            )
          : null,
    );

    return IntrinsicHeight(
      key: const Key('dashboardReadingLine'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: leadWidth,
            child: _SavingsItem(summary: summary, previous: previous),
          ),
          const _Separator(),
          Flexible(
            child: figure(
              id: 'income',
              label: l10n.dashboardStatIncome,
              amountMinor: summary.incomeMinor,
              deltaPct: summary.incomeDeltaPct,
            ),
          ),
          const _Separator(),
          Flexible(
            child: figure(
              id: 'expense',
              label: l10n.dashboardStatExpense,
              amountMinor: -summary.expenseMinor,
              deltaPct: summary.expenseDeltaPct,
              riseIsBad: true,
            ),
          ),
          const _Separator(),
          Flexible(
            child: figure(
              id: 'net',
              label: l10n.dashboardStatNet,
              amountMinor: summary.netMinor,
              deltaPct: summary.netDeltaPct,
              // The only sign-coloured figure of the line (`04` §Behaviour).
              colorize: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical `line` hairline with the summary line's 40 px either side.
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
    child: SizedBox(width: 1, child: ColoredBox(color: context.colors.line)),
  );
}

/// The lead: « Taux d’épargne », the rate at 40 px, the repère on a scale of
/// 0 to twice the goal with the goal's mark, then the goal status.
class _SavingsItem extends StatelessWidget {
  const _SavingsItem({required this.summary, required this.previous});

  final DashboardSummary summary;
  final DateTime previous;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final goal = formatRatioPct(savingsRateGoal, locale, decimalDigits: 0);
    final hasRate = summary.hasSavingsRate;
    final rate = formatRatioPct(summary.savingsRate, locale);
    final secondary = textTheme.bodySmall!.copyWith(
      color: colors.textSecondary,
    );
    final delta = l10n.dashboardSavingsDeltaSince(
      formatSignedMagnitude(summary.savingsRateDeltaPct, locale),
      previous,
    );

    return Column(
      key: const Key('dashboardReading-savings'),
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.dashboardStatSavingsRate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.statLabel,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          hasRate ? rate : l10n.dashboardNoValue,
          key: const Key('dashboardSavingsRateValue'),
          maxLines: 1,
          style: tabularNumberStyle(
            textTheme.displayLarge!,
          ).copyWith(color: hasRate ? colors.text : colors.textTertiary),
        ),
        if (hasRate) ...[
          const SizedBox(height: AppSpacing.sm),
          RepereMeter(
            key: const Key('dashboardSavingsGoalBar'),
            fraction: summary.savingsRateMeterFraction,
            markFraction: DashboardSummary.savingsGoalMarkFraction,
            markLabel: l10n.dashboardSavingsGoalMark(goal),
            tone: summary.savingsGoalReached
                ? RepereTone.done
                : RepereTone.normal,
            semanticLabel: rate,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            key: const Key('dashboardSavingsGoalLine'),
            children: [
              if (summary.savingsGoalReached) ...[
                StatusText(
                  key: const Key('dashboardSavingsGoalReached'),
                  label: l10n.dashboardSavingsGoalReached,
                  tone: StatusTone.positive,
                  icon: LucideIcons300.check,
                ),
                Flexible(
                  child: Text(
                    ' · $delta',
                    key: const Key('dashboardSavingsDelta'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tabularNumberStyle(secondary),
                  ),
                ),
              ] else
                Flexible(
                  child: Text(
                    '${l10n.dashboardSavingsGoalPending(goal)} · $delta',
                    key: const Key('dashboardSavingsDelta'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tabularNumberStyle(secondary),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A money item: label, the signed figure at 28 px, then the trend line.
class _FigureItem extends StatelessWidget {
  const _FigureItem({
    super.key,
    required this.id,
    required this.label,
    required this.amountMinor,
    required this.currency,
    required this.colorize,
    required this.trend,
  });

  final String id;
  final String label;

  /// `null` for a month without data: the figure is « — ».
  final int? amountMinor;
  final String currency;
  final bool colorize;
  final _Trend? trend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final amountMinor = this.amountMinor;
    final trend = this.trend;

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
        const SizedBox(height: AppSpacing.xsPlus),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: amountMinor == null
              ? Text(
                  l10n.dashboardNoValue,
                  key: Key('dashboardReadingValue-$id'),
                  style: textTheme.displayMedium?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                )
              : AmountText(
                  key: Key('dashboardReadingValue-$id'),
                  amountMinor: amountMinor,
                  currency: currency,
                  showPositiveSign: true,
                  colorize: colorize,
                  style: textTheme.displayMedium,
                ),
        ),
        if (trend != null) ...[
          const SizedBox(height: AppSpacing.xsPlus),
          trend,
        ],
      ],
    );
  }
}

/// « ↗ 2,1 % vs avril »: an icon for the direction, an unsigned percent in
/// `positive` when the news is good and `negative` when it is bad, then the
/// month compared with (`00` §2.3). Flat is `minus` in `textSecondary`.
class _Trend extends StatelessWidget {
  const _Trend({
    required this.id,
    required this.deltaPct,
    required this.riseIsBad,
    required this.caption,
  });

  final String id;
  final double deltaPct;
  final bool riseIsBad;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final color = trendColor(context, deltaPct, invert: riseIsBad);

    return Row(
      key: Key('dashboardReadingTrend-$id'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          switch (deltaPct) {
            > 0 => LucideIcons300.trendingUp,
            < 0 => LucideIcons300.trendingDown,
            _ => LucideIcons300.minus,
          },
          size: AppSizes.iconStatus,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          formatRatioPct(deltaPct.abs() / 100, locale),
          key: Key('dashboardReadingDelta-$id'),
          style: tabularNumberStyle(
            textTheme.bodySmall!,
          ).copyWith(color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The colour of a month-over-month movement: `positive` when it is good news,
/// `negative` when it is bad, `textSecondary` when flat. [invert] is for a
/// figure where a rise is the bad outcome (expenses).
Color trendColor(BuildContext context, double delta, {bool invert = false}) =>
    switch (delta) {
      > 0 => invert ? context.colors.negative : context.colors.positive,
      < 0 => invert ? context.colors.positive : context.colors.negative,
      _ => context.colors.textSecondary,
    };

/// U+2212, matching [AmountText]'s convention rather than the ASCII hyphen
/// `intl` emits.
const _minusSign = '−';

/// A signed number with one decimal and no unit: « +1,9 », « −0,4 ».
String formatSignedMagnitude(double value, String locale) {
  final magnitude = NumberFormat('0.0', locale).format(value.abs());
  final sign = value > 0
      ? '+'
      : value < 0
      ? _minusSign
      : '';
  return '$sign$magnitude';
}

/// A `0..1` ratio as the locale writes a percentage: « 22,3 % » in French,
/// "22.3%" in English.
String formatRatioPct(double ratio, String locale, {int decimalDigits = 1}) =>
    NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: decimalDigits,
    ).format(ratio).replaceAll('-', _minusSign);
