import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/loan_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';
import 'scenario_list.dart';

/// One row of the comparison: a label and how each column fills it. `null`
/// is a figure that does not apply to that scenario: printed as a dash,
/// never as a zero.
typedef _CompareRow = ({
  String id,
  String label,
  bool emphasised,
  bool sectionBreak,
  String? Function(ComparisonColumn column) value,
});

/// The comparison (`14-simulateur.md` §Comparison): it replaces the reading
/// pane, padding 24 32, and sets up to three scenarios side by side with the
/// same rows in every column, so each line reads across.
///
/// Every figure is recomputed by the engine for this view: a saved scenario
/// never carries its results.
class ScenarioComparison extends ConsumerWidget {
  const ScenarioComparison({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final comparison = state.comparison;

    return Padding(
      key: const Key('comparison'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.simulatorCompareTitle(state.selection.length),
                  key: const Key('compareTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                key: const Key('compareClose'),
                label: l10n.simulatorCompareClose,
                icon: LucideIcons300.x,
                variant: AppButtonVariant.ghost,
                onPressed: ref
                    .read(simulatorControllerProvider.notifier)
                    .closeComparison,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: switch (comparison) {
              AsyncData(:final value) => SingleChildScrollView(
                child: _CompareTable(state: state, columns: value),
              ),
              AsyncError() => Align(
                alignment: AlignmentDirectional.topStart,
                child: NoteLine(
                  key: const Key('compareFailed'),
                  icon: LucideIcons300.triangleAlert,
                  text: l10n.simulatorCompareFailed,
                ),
              ),
              _ => const SkeletonPulse(
                key: Key('compareLoading'),
                child: SkeletonBlock(height: double.infinity),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.state, required this.columns});

  final SimulatorState state;
  final List<ComparisonColumn> columns;

  static const _labelWidth = AppSimulator.compareLabelColumn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final household = state.household;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: household.currency,
      locale: locale,
    );
    // Insurance at zero is a scenario without insurance, not a free one.
    String? moneyOrAbsent(int? minor) =>
        minor == null || minor == 0 ? null : money(minor);

    final rows = <_CompareRow>[
      (
        id: 'price',
        label: l10n.simulatorPrice,
        emphasised: false,
        sectionBreak: false,
        value: (c) => switch (c.terms.propertyPriceMinor) {
          final price? => money(price),
          null => null,
        },
      ),
      (
        id: 'downPayment',
        label: l10n.simulatorDownPayment,
        emphasised: false,
        sectionBreak: false,
        value: (c) => switch (c.terms.downPaymentMinor) {
          final down? => money(down),
          null => null,
        },
      ),
      (
        id: 'fees',
        label: l10n.simulatorFees,
        emphasised: false,
        sectionBreak: false,
        value: (c) => money(c.terms.upfrontFeesMinor),
      ),
      (
        id: 'principal',
        label: l10n.simulatorPrincipal,
        emphasised: false,
        sectionBreak: false,
        value: (c) => money(c.terms.principalMinor),
      ),
      (
        id: 'rate',
        label: l10n.simulatorRate,
        emphasised: false,
        sectionBreak: false,
        value: (c) => formatRate(c.terms.annualRateBps, locale),
      ),
      (
        id: 'term',
        label: l10n.simulatorTerm,
        emphasised: false,
        sectionBreak: false,
        value: (c) => termLabel(l10n, c.terms.termMonths),
      ),
      (
        id: 'insurance',
        label: l10n.simulatorInsurance,
        emphasised: false,
        sectionBreak: false,
        value: (c) => moneyOrAbsent(c.terms.insuranceMonthlyMinor),
      ),
      (
        id: 'instalment',
        label: l10n.simulatorInstalmentLabel,
        emphasised: true,
        sectionBreak: true,
        value: (c) => money(c.result.totalInstalmentMinor),
      ),
      (
        id: 'interest',
        label: l10n.simulatorCompareTotalInterest,
        emphasised: false,
        sectionBreak: false,
        value: (c) => money(c.result.totalInterestMinor),
      ),
      (
        id: 'totalInsurance',
        label: l10n.simulatorCompareTotalInsurance,
        emphasised: false,
        sectionBreak: false,
        value: (c) => moneyOrAbsent(c.result.totalInsuranceMinor),
      ),
      (
        id: 'cost',
        label: l10n.simulatorCostLabel,
        emphasised: true,
        sectionBreak: false,
        value: (c) => money(c.result.totalCostMinor),
      ),
      (
        id: 'costShare',
        label: l10n.simulatorCompareCostShare,
        emphasised: false,
        sectionBreak: false,
        value: (c) => switch (c.result.costOverPriceBps) {
          final share? => formatBps(share, locale),
          null => null,
        },
      ),
      (
        id: 'taeg',
        label: l10n.simulatorCompareTaeg,
        emphasised: false,
        sectionBreak: false,
        value: (c) => formatRate(c.result.taegBps, locale),
      ),
      (
        id: 'ratio',
        label: l10n.simulatorRatioLabel,
        emphasised: false,
        sectionBreak: true,
        value: (c) => switch (c.result.debtRatioBps) {
          final ratio? => formatBps(ratio, locale),
          null => null,
        },
      ),
      (
        id: 'ratioWithExisting',
        label: l10n.simulatorCompareWithExisting,
        emphasised: false,
        sectionBreak: false,
        value: (c) => switch (c.ratioWithExistingBps) {
          final ratio? => formatBps(ratio, locale),
          null => null,
        },
      ),
    ];

    final limit = columns.isEmpty
        ? null
        : formatBps(columns.first.result.hcsf.limitBps, locale, digits: 0);
    final income = household.monthlyIncomeMinor;
    final incomeKnown =
        income != null &&
        columns.any((column) => column.result.debtRatioBps != null);

    final cellStyle = tabularNumberStyle(textTheme.bodyMedium!);
    const cellPadding = EdgeInsetsDirectional.only(end: AppSpacing.smPlus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The header: each scenario's name, « en cours » under the live one.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: _labelWidth),
              for (final column in columns)
                Expanded(
                  child: Padding(
                    padding: cellPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          column.label ??
                              liveScenarioName(l10n, locale, state.inputs),
                          key: Key('compareHeader-${column.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: textTheme.labelLarge,
                        ),
                        if (column.isLive)
                          Text(
                            l10n.simulatorLiveMarker,
                            key: const Key('compareLiveMarker'),
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final row in rows)
          Container(
            key: Key('compareRow-${row.id}'),
            height: AppSizes.tableRow,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: row.sectionBreak ? colors.lineStrong : colors.line,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Padding(
                    padding: cellPadding,
                    child: Text(
                      row.label,
                      key: Key('compareLabel-${row.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (row.emphasised
                                  ? textTheme.titleSmall!
                                  : textTheme.bodyMedium!)
                              .copyWith(color: colors.textSecondary),
                    ),
                  ),
                ),
                for (final column in columns)
                  Expanded(
                    child: Padding(
                      padding: cellPadding,
                      child: Builder(
                        builder: (context) {
                          final value = row.value(column);
                          return Text(
                            value ?? l10n.simulatorNoValue,
                            key: Key('compare-${row.id}-${column.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: cellStyle.copyWith(
                              fontWeight: row.emphasised
                                  ? textTheme.titleSmall!.fontWeight
                                  : null,
                              color: value == null
                                  ? colors.textTertiary
                                  : colors.text,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (limit != null) ...[
          const SizedBox(height: AppSpacing.md),
          NoteLine(
            key: const Key('compareFoot'),
            text: incomeKnown
                ? l10n.simulatorCompareFoot(
                    household.incomeSource == IncomeSource.declared
                        ? 'declared'
                        : 'ledger',
                    money(income),
                    limit,
                  )
                : l10n.simulatorCompareFootUnknown(limit),
          ),
        ],
      ],
    );
  }
}
