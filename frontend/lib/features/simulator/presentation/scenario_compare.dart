import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';
import 'scenario_list.dart';
import 'simulator_labels.dart';

/// One row of the comparison: a label and how each column fills it. `null`
/// is a figure that does not apply to that scenario — printed as a dash,
/// never as a zero.
typedef _CompareRow = ({
  String id,
  String label,
  bool emphasised,
  bool sectionBreak,
  String? Function(ComparisonColumn column) value,
});

/// The comparison card (`14-simulateur.md` ③): up to three scenarios side by
/// side with the same rows in every column, so each line reads across.
///
/// Replaces the right column while open. Every figure is recomputed by the
/// engine for this view — a saved scenario never carries its results.
class ScenarioCompareCard extends ConsumerWidget {
  const ScenarioCompareCard({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final comparison = state.comparison;

    return AppCard(
      key: const Key('compareCard'),
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.simulatorCompareTitle(state.selection.length),
                      key: const Key('compareTitle'),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.simulatorCompareSubtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('compareClose'),
                onPressed: ref
                    .read(simulatorControllerProvider.notifier)
                    .closeComparison,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(l10n.simulatorCompareClose),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: switch (comparison) {
              AsyncData(:final value) => SingleChildScrollView(
                child: _CompareTable(state: state, columns: value),
              ),
              AsyncError() => Center(
                child: Text(
                  l10n.simulatorCompareFailed,
                  key: const Key('compareFailed'),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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

  static const _labelWidth = 190.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
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
        value: (c) => l10n.simulatorMonths(c.terms.termMonths),
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

    final valueStyle = tabularNumberStyle(textTheme.bodyMedium!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceRowHover,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              const SizedBox(width: _labelWidth),
              for (final column in columns)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          column.label ??
                              liveScenarioName(l10n, locale, state.inputs),
                          key: Key('compareHeader-${column.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (column.isLive) ...[
                        const SizedBox(width: AppSpacing.sm - 2),
                        SimulatorMarkerPill(label: l10n.simulatorLivePill),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final row in rows)
          Container(
            key: Key('compareRow-${row.id}'),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: row.emphasised
                  ? AppColors.iris.withValues(alpha: 0.05)
                  : null,
              border: Border(
                top: row.sectionBreak
                    ? const BorderSide(color: AppColors.border)
                    : BorderSide.none,
                bottom: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: row.emphasised ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                for (final column in columns)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final value = row.value(column);
                        return Text(
                          value ?? '—',
                          key: Key('compare-${row.id}-${column.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: valueStyle.copyWith(
                            fontWeight: row.emphasised ? FontWeight.w700 : null,
                            color: value == null
                                ? AppColors.textDisabled
                                : AppColors.textPrimary,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        if (limit != null) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          Text(
            incomeKnown
                ? l10n.simulatorCompareFoot(
                    household.incomeSource == IncomeSource.declared
                        ? 'declared'
                        : 'ledger',
                    money(income),
                    limit,
                  )
                : l10n.simulatorCompareFootUnknown(limit),
            key: const Key('compareFoot'),
            style: AppTextStyles.helper.copyWith(
              fontSize: 11,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ],
    );
  }
}
