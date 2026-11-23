import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/loan_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/loan_summary_line.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';

/// The summary line (`14-simulateur.md` §Reading pane, 1): the shared
/// [LoanSummaryLine] over the live simulation. None of its figures depends on
/// the existing-loans toggle.
class SimulationSummaryLine extends StatelessWidget {
  const SimulationSummaryLine({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    final terms = state.inputs.terms;

    return LoanSummaryLine(
      key: const Key('simulatorSummaryLine'),
      currency: result?.currency ?? state.household.currency,
      emptyCaption: AppLocalizations.of(context)!.simulatorInstalmentEmpty,
      figures: result == null || terms == null
          ? null
          : (
              totalInstalmentMinor: result.totalInstalmentMinor,
              monthlyPaymentMinor: result.monthlyPaymentMinor,
              insuranceMonthlyMinor: terms.insuranceMonthlyMinor,
              termMonths: terms.termMonths,
              totalCostMinor: result.totalCostMinor,
              totalInterestMinor: result.totalInterestMinor,
              totalInsuranceMinor: result.totalInsuranceMinor,
              upfrontFeesMinor: terms.upfrontFeesMinor,
              taegBps: result.taegBps,
            ),
    );
  }
}

/// « Lecture HCSF » (`14-simulateur.md` §Reading pane, 3): the debt ratio
/// against 35 %, the term against 25 years and the borrowing capacity at the
/// reference, each on its repère, as a reading.
///
/// Above a reference only the repère turns `over` and the heading gains a
/// `warning` status text; nothing else changes tone and nothing is blocked.
/// With no income there is no ratio and no capacity: the two columns merge
/// into one block that says why and offers the way out.
class HcsfReading extends StatelessWidget {
  const HcsfReading({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final result = state.result;
    final hcsf = result?.hcsf;
    final over =
        hcsf != null && (hcsf.withinRatio == false || !hcsf.withinTerm);
    const gap = SizedBox(width: AppSpacing.xxl);

    final Widget columns;
    if (result != null && !state.incomeKnown) {
      columns = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(flex: 2, child: _UnknownIncomeBlock()),
          gap,
          Expanded(child: _TermColumn(state: state)),
        ],
      );
    } else {
      columns = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _RatioColumn(state: state)),
          gap,
          Expanded(child: _TermColumn(state: state)),
          gap,
          Expanded(child: _CapacityColumn(state: state)),
        ],
      );
    }

    return Column(
      key: const Key('hcsfReading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(l10n.simulatorHcsfTitle, style: textTheme.titleSmall),
            if (over) ...[
              const SizedBox(width: AppSpacing.smPlus),
              StatusText(
                key: const Key('hcsfOverStatus'),
                label: l10n.simulatorHcsfOver,
                tone: StatusTone.warning,
              ),
            ],
            const SizedBox(width: AppSpacing.md),
            // Body text, never a tooltip: the app makes no lending decision
            // and says so where the reading is shown (`00` §14, rule 10).
            Expanded(
              child: Text(
                l10n.simulatorHcsfCaveat,
                key: const Key('hcsfCaveat'),
                textAlign: TextAlign.end,
                style: textTheme.bodySmall?.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        columns,
      ],
    );
  }
}

class _RatioColumn extends StatelessWidget {
  const _RatioColumn({required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final result = state.result;
    final ratio = result?.debtRatioBps;
    if (result == null || ratio == null) {
      return _ReadingColumn(
        label: l10n.simulatorRatioLabel,
        value: null,
        valueKey: const Key('hcsfRatioValue'),
        caption: l10n.simulatorRatioEmpty,
        captionKey: const Key('hcsfRatioCaption'),
      );
    }
    final household = state.household;
    final income = household.monthlyIncomeMinor;
    final withExisting = state.chargeWithExistingMinor;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: result.currency,
      locale: locale,
    );

    final source = household.incomeSource == IncomeSource.declared
        ? 'declared'
        : 'ledger';
    final limit = formatBps(result.hcsf.limitBps, locale, digits: 0);

    return _ReadingColumn(
      label: l10n.simulatorRatioLabel,
      value: formatBps(ratio, locale),
      valueKey: const Key('hcsfRatioValue'),
      // The tone follows the API's `within_ratio` flag, not a comparison
      // made here. Above 70 % the fill clamps; the number stays exact.
      meter: RepereMeter(
        key: const Key('hcsfRatioGauge'),
        fraction: ratio / AppSimulator.ratioScaleBps,
        markFraction: result.hcsf.limitBps / AppSimulator.ratioScaleBps,
        markLabel: l10n.simulatorReference(limit),
        tone: result.hcsf.withinRatio == false
            ? RepereTone.over
            : RepereTone.normal,
        semanticLabel: formatBps(ratio, locale),
      ),
      caption: income == null
          ? null
          : withExisting != null
          ? l10n.simulatorRatioCaptionWithExisting(
              money(withExisting),
              money(result.totalInstalmentMinor),
              money(household.existingChargeMinor),
              source,
              money(income),
            )
          : l10n.simulatorRatioCaption(
              money(result.totalInstalmentMinor),
              source,
              money(income),
            ),
      captionKey: const Key('hcsfRatioCaption'),
    );
  }
}

class _TermColumn extends StatelessWidget {
  const _TermColumn({required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final term = state.inputs.termMonths;
    final hcsf = state.result?.hcsf;

    return _ReadingColumn(
      label: l10n.simulatorTerm,
      value: termLabel(l10n, term),
      valueKey: const Key('hcsfTermValue'),
      meter: hcsf == null
          ? null
          : RepereMeter(
              key: const Key('hcsfTermGauge'),
              fraction: term / AppSimulator.termScaleMonths,
              markFraction: hcsf.maxTermMonths / AppSimulator.termScaleMonths,
              markLabel: l10n.simulatorReference(
                termLabel(l10n, hcsf.maxTermMonths),
              ),
              tone: hcsf.withinTerm ? RepereTone.normal : RepereTone.over,
              semanticLabel: termLabel(l10n, term),
            ),
      caption: hcsf == null
          ? null
          : !hcsf.withinTerm
          ? l10n.simulatorTermOverReference
          : term == hcsf.maxTermMonths
          ? l10n.simulatorTermAtReference
          : l10n.simulatorTermUnderReference,
      captionKey: const Key('hcsfTermCaption'),
    );
  }
}

class _CapacityColumn extends StatelessWidget {
  const _CapacityColumn({required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final result = state.result;
    final capacity = result?.maxBorrowableMinor;
    final available = result?.availableInstalmentMinor;
    if (result == null) {
      return _ReadingColumn(
        label: l10n.simulatorCapacityLabel,
        value: null,
        valueKey: const Key('hcsfCapacityValue'),
        caption: l10n.simulatorCapacityEmpty,
        captionKey: const Key('hcsfCapacityCaption'),
        inline: false,
      );
    }

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: result.currency,
      locale: locale,
    );
    final limit = formatBps(result.hcsf.limitBps, locale, digits: 0);

    // A small capacity is explained by its cause: when the current loans are
    // what fill the room under the reference, the caption says so.
    final crowdedByExisting =
        state.countsExistingLoans && result.hcsf.withinRatio == false;

    return _ReadingColumn(
      label: l10n.simulatorCapacityLabel,
      value: capacity == null ? null : money(capacity),
      valueKey: const Key('hcsfCapacityValue'),
      caption: available == null
          ? null
          : crowdedByExisting
          ? l10n.simulatorCapacityCaptionExisting(money(available), limit)
          : l10n.simulatorCapacityCaption(money(available), limit),
      captionKey: const Key('hcsfCapacityCaption'),
      inline: false,
    );
  }
}

/// One reading: the label and its figure at 20 px (on one line, or the
/// figure under the label when [inline] is off), the repère when there is
/// one, then the caption 12 `textTertiary`, 6 px apart.
class _ReadingColumn extends StatelessWidget {
  const _ReadingColumn({
    required this.label,
    required this.value,
    this.valueKey,
    this.meter,
    this.caption,
    this.captionKey,
    this.inline = true,
  });

  final String label;

  /// `null` draws the dash.
  final String? value;
  final Key? valueKey;
  final Widget? meter;
  final String? caption;
  final Key? captionKey;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textStyles.statLabel,
    );
    final valueText = Text(
      value ?? l10n.simulatorNoValue,
      key: valueKey,
      maxLines: 1,
      style: tabularNumberStyle(
        textTheme.displaySmall!,
      ).copyWith(color: value == null ? colors.textTertiary : colors.text),
    );
    const gap = SizedBox(height: AppSpacing.xsPlus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inline)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: labelText),
              const SizedBox(width: AppSpacing.sm),
              valueText,
            ],
          )
        else ...[
          labelText,
          gap,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(fit: BoxFit.scaleDown, child: valueText),
          ),
        ],
        if (meter != null) ...[gap, meter!],
        if (caption != null) ...[
          gap,
          Text(
            caption!,
            key: captionKey,
            style: tabularNumberStyle(
              textTheme.bodySmall!,
            ).copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// Income unknown: the ratio and capacity columns merge into one block, the
/// dash, why, and the way out.
class _UnknownIncomeBlock extends StatelessWidget {
  const _UnknownIncomeBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    return Column(
      key: const Key('hcsfUnknownIncome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.simulatorNoValue,
          key: const Key('hcsfRatioValue'),
          style: textTheme.displaySmall!.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.xsPlus),
        Text(
          l10n.simulatorRatioUnknown,
          key: const Key('hcsfUnknownIncomeText'),
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.smPlus),
        AppButton(
          key: const Key('hcsfDeclareIncome'),
          label: l10n.simulatorDeclareIncome,
          // Paramètres → Préférences holds the one field that edits the
          // income (`09-settings.md` §Préférences).
          onPressed: () => context.go(SettingsScreen.incomePath),
        ),
      ],
    );
  }
}
