import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/bar_charts.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_trends.dart';

/// « Épargne mensuelle » (`docs/design/04-dashboard.md` §3b): what each of the
/// twelve months ending on the selected one put aside, as bars by sign. The
/// heading carries the 12-month average, signed and coloured, with « en
/// moyenne sur 12 mois ». The month in progress, when the window includes it,
/// is hatched.
class MonthlySavings extends StatelessWidget {
  const MonthlySavings({super.key, required this.trends});

  final DashboardTrends trends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final series = trends.savingsSeries;
    final values = [for (final point in series) point.savedMinor];
    // Standalone abbreviations (« déc. », « janv. »): they label an axis.
    final monthFormat = DateFormat('LLL', locale);
    final labels = [
      for (final point in series) monthFormat.format(point.month),
    ];
    String valueLabel(num minor) => NumberFormat.compactSimpleCurrency(
      locale: locale,
      name: trends.currency,
    ).format(minor / 100).replaceAll('-', '−');
    final tooltips = [
      for (final point in series)
        TextSpan(
          children: [
            TextSpan(
              text:
                  '${_capitalize(DateFormat.yMMMM(locale).format(point.month))}\n',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            TextSpan(
              text: formatAmount(
                amountMinor: point.savedMinor,
                currency: trends.currency,
                locale: locale,
                showPositiveSign: true,
              ),
              style: tabularNumberStyle(textTheme.bodyMedium!).copyWith(
                color: point.savedMinor < 0
                    ? colors.negative
                    : point.savedMinor > 0
                    ? colors.positive
                    : colors.text,
              ),
            ),
          ],
        ),
    ];

    return Column(
      key: const Key('dashboardMonthlySavings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.dashboardSavingsTrendTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (series.isNotEmpty) ...[
                AmountText(
                  key: const Key('dashboardAverageSaved'),
                  amountMinor: trends.averageSavedMinor,
                  currency: trends.currency,
                  showPositiveSign: true,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.dashboardSavingsTrendAverage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: SignedBarChart(
            key: const Key('dashboardSavingsBars'),
            values: values,
            labels: labels,
            provisional: trends.inProgress,
            valueLabel: valueLabel,
            tooltips: tooltips,
            minStep: 100,
          ),
        ),
      ],
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
