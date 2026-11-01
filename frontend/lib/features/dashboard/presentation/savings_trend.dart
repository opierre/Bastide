import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../l10n/app_localizations.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_trends.dart';
import 'savings_chart.dart';

/// « Évolution de l'épargne » — what each of the last twelve months put aside, as bars or
/// as a line, headed by the monthly average (see `docs/design/04-dashboard.md` §Row 2).
class SavingsTrendChart extends ConsumerWidget {
  const SavingsTrendChart({super.key, required this.trends});

  final DashboardTrends trends;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final view = ref.watch(savingsChartViewProvider);
    final locale = Localizations.localeOf(context).toString();
    final series = trends.savingsSeries;
    // Standalone month abbreviations ("déc.", "janv."), not the genitive form a full date
    // would take — these label an axis tick, not a date.
    final monthFormat = DateFormat('LLL', locale);
    final textTheme = Theme.of(context).textTheme;

    return ChartContainer(
      title: l10n.dashboardSavingsTrendTitle,
      subtitle: l10n.dashboardSavingsTrendSubtitle(series.length),
      // The view switch and the headline sit on the card's trailing edge, level with the
      // title, so the chart owns the card's whole body.
      trailing: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _switchWidth,
            child: AppSegmented<SavingsChartView>(
              key: const Key('savingsViewSwitch'),
              value: view,
              onChanged: ref.read(savingsChartViewProvider.notifier).set,
              segments: [
                AppSegment(
                  key: const Key('savingsViewBars'),
                  value: SavingsChartView.bars,
                  label: l10n.dashboardSavingsViewBars,
                ),
                AppSegment(
                  key: const Key('savingsViewLine'),
                  value: SavingsChartView.line,
                  label: l10n.dashboardSavingsViewLine,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _Header(trends: trends),
        ],
      ),
      child: SavingsChart(
        view: view,
        values: [for (final point in series) point.savedMinor],
        labels: [
          for (final point in series)
            _capitalize(monthFormat.format(point.month)),
        ],
        // Compact figures on the gridlines, as on the Synthèse's « Patrimoine net », so a
        // bar's height reads as an amount and not only as a shape.
        valueLabel: (minor) => NumberFormat.compactSimpleCurrency(
          locale: locale,
          name: trends.currency,
        ).format(minor / 100).replaceAll('-', '−'),
        // Hovering a month names what it put aside, signed and colored like any movement.
        tooltips: [
          for (final point in series)
            TextSpan(
              children: [
                TextSpan(
                  text:
                      '${_capitalize(DateFormat.yMMMM(locale).format(point.month))}\n',
                  style: tabularNumberStyle(textTheme.labelSmall!),
                ),
                TextSpan(
                  text: formatAmount(
                    amountMinor: point.savedMinor,
                    currency: trends.currency,
                    locale: locale,
                    showPositiveSign: true,
                  ),
                  style: tabularNumberStyle(textTheme.bodySmall!).copyWith(
                    color: point.savedMinor < 0
                        ? AppColors.negative
                        : AppColors.positive,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Two short labels (« Barres » / « Courbe »), sized so the French pair fits without
/// crowding the title on the narrowest desktop window.
const _switchWidth = 128.0;

class _Header extends StatelessWidget {
  const _Header({required this.trends});

  final DashboardTrends trends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AmountText(
          amountMinor: trends.averageSavedMinor,
          currency: trends.currency,
          showPositiveSign: true,
          style: textTheme.headlineLarge,
          key: const Key('dashboardAverageSaved'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.dashboardSavingsTrendAverage,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
