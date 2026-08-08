import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/area_line.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_trends.dart';

/// « Évolution de l'épargne » — the cumulative-savings area line, headed by the running total
/// and what the latest month added (see `docs/design/04-dashboard.md` §Row 2).
class SavingsTrendChart extends StatelessWidget {
  const SavingsTrendChart({super.key, required this.trends});

  final DashboardTrends trends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final series = trends.savingsSeries;
    // Standalone month abbreviations ("déc.", "janv."), not the genitive form a full date
    // would take — these label an axis tick, not a date.
    final monthFormat = DateFormat('LLL', locale);

    return ChartContainer(
      title: l10n.dashboardSavingsTrendTitle,
      subtitle: l10n.dashboardSavingsTrendSubtitle(series.length),
      // The running total and the latest month's step head the card from its trailing edge,
      // level with the title, rather than sitting above the plot — the chart then owns the
      // card's whole body, which is what keeps the line readable as the panel narrows.
      trailing: _Header(trends: trends),
      child: AreaLine(
        values: [for (final point in series) point.cumulativeMinor],
        labels: [
          for (final point in series) _capitalize(monthFormat.format(point.month)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.trends});

  final DashboardTrends trends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final delta = trends.latestMonthNetMinor;
    final latestMonth = trends.latestMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AmountText(
          amountMinor: trends.totalSavedMinor,
          currency: trends.currency,
          // A running total is a neutral figure — the colored movement is the delta below it.
          colorize: false,
          style: textTheme.headlineLarge,
          key: const Key('dashboardTotalSaved'),
        ),
        if (latestMonth != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.dashboardSavingsTrendDelta(
              formatAmount(
                amountMinor: delta,
                currency: trends.currency,
                locale: locale,
                showPositiveSign: true,
              ),
              DateFormat('LLLL', locale).format(latestMonth),
            ),
            key: const Key('dashboardSavingsDelta'),
            style: tabularNumberStyle(textTheme.labelSmall!).copyWith(
              fontWeight: FontWeight.w400,
              color: delta < 0 ? AppColors.negative : AppColors.positive,
            ),
          ),
        ],
      ],
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
