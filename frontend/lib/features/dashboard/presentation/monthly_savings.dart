import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/bar_charts.dart';
import '../../../core/widgets/chart_frame.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_trends.dart';

/// « Épargne mensuelle » (`docs/design/04-dashboard.md` §3b): what each of the
/// last twelve months put aside, as bars by sign (the default) or as a line.
/// The heading carries the « Barres · Courbe » switch, then the 12-month
/// average, signed and coloured, with « en moyenne sur 12 mois ». The month in
/// progress is hatched on the bars and drawn hollow on the line.
class MonthlySavings extends ConsumerWidget {
  const MonthlySavings({super.key, required this.trends});

  final DashboardTrends trends;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final view = ref.watch(savingsChartViewProvider);
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
    final provisional = series.isEmpty ? <int>{} : {series.length - 1};
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
              AppSegmented<SavingsChartView>(
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
              if (series.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.smPlus),
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
          child: switch (view) {
            SavingsChartView.bars => SignedBarChart(
              key: const Key('dashboardSavingsBars'),
              values: values,
              labels: labels,
              provisional: provisional,
              valueLabel: valueLabel,
              tooltips: tooltips,
              minStep: 100,
            ),
            SavingsChartView.line => SavingsLineChart(
              key: const Key('dashboardSavingsLine'),
              values: values,
              labels: labels,
              provisional: provisional,
              valueLabel: valueLabel,
              tooltips: tooltips,
            ),
          },
        ),
      ],
    );
  }
}

/// The line view of « Épargne mensuelle »: the line recipe of `00` §9 on the
/// shared [ChartFrame] (2 px `accent` line, round joins, `accent` area at
/// 10 % down to zero), with a dot per month in its sign's colour so the sign
/// never rests on the line's position alone. A month in [provisional] takes a
/// hollow dot: it is not yet a fact.
class SavingsLineChart extends StatelessWidget {
  const SavingsLineChart({
    super.key,
    required this.values,
    required this.labels,
    required this.valueLabel,
    this.provisional = const {},
    this.tooltips,
  });

  final List<int> values;
  final List<String> labels;
  final String Function(num value) valueLabel;
  final Set<int> provisional;
  final List<InlineSpan>? tooltips;

  @override
  Widget build(BuildContext context) {
    return ChartFrame(
      scaleValues: [...values, 0],
      labels: labels,
      valueLabel: valueLabel,
      tooltips: tooltips,
      minStep: 100,
      joinsLine: true,
      slotKeyPrefix: 'savingsLineSlot',
      tooltipKey: const Key('savingsLineTooltip'),
      anchors: (g) => [
        for (var i = 0; i < values.length; i++) Offset(g.x(i), g.y(values[i])),
      ],
      paintSeries: (canvas, g, colors, hovered) {
        if (values.isEmpty) return;
        final line = Path();
        for (var i = 0; i < values.length; i++) {
          final point = Offset(g.x(i), g.y(values[i]));
          if (i == 0) {
            line.moveTo(point.dx, point.dy);
          } else {
            line.lineTo(point.dx, point.dy);
          }
        }
        if (values.length > 1) {
          final zero = g.y(0);
          final area = Path.from(line)
            ..lineTo(g.x(values.length - 1), zero)
            ..lineTo(g.x(0), zero)
            ..close();
          canvas
            ..drawPath(area, ChartPaints.area(colors.accent))
            ..drawPath(line, ChartPaints.stroke(colors.accent));
        }
        final large = {values.length - 1, ?hovered};
        for (var i = 0; i < values.length; i++) {
          final value = values[i];
          final color = value < 0 ? colors.negative : colors.positive;
          final center = Offset(g.x(i), g.y(value));
          final radius = large.contains(i)
              ? AppChart.currentDotRadius
              : AppChart.pointDotRadius;
          if (provisional.contains(i)) {
            ChartPaints.hollowDot(colors, canvas, center, radius, color);
          } else {
            ChartPaints.dot(colors, canvas, center, radius, color);
          }
        }
      },
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
