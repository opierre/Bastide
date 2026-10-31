import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_trends.dart';
import 'savings_bars.dart';

/// « Évolution de l'épargne » — what each of the last twelve months put aside, one bar per
/// month, headed by the monthly average (see `docs/design/04-dashboard.md` §Row 2).
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
    final textTheme = Theme.of(context).textTheme;

    return ChartContainer(
      title: l10n.dashboardSavingsTrendTitle,
      subtitle: l10n.dashboardSavingsTrendSubtitle(series.length),
      // The headline sits on the card's trailing edge, level with the title, so the bars own
      // the card's whole body.
      trailing: _Header(trends: trends),
      child: SavingsBars(
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
