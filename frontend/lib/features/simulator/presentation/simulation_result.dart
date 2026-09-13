import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';
import 'simulator_labels.dart';

/// The ratio gauge's fixed scale on this panel, in bps: 0–70 % — wider than
/// Crédits' 0–60 %, so an over-reference reading with the existing loans
/// counted still sits inside it (`14-simulateur.md` §Notes).
const simulatorRatioScaleBps = 7000;

/// The result row (`14-simulateur.md` §Result row): the monthly instalment, the
/// total cost and the indicative TAEG, `1.25fr 1fr 1fr`.
///
/// Every figure is the API's. The row never changes tone: an over-reference
/// reading tints the HCSF card alone.
class SimulationResultRow extends StatelessWidget {
  const SimulationResultRow({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final result = state.result;
    final terms = state.inputs.terms;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: result?.currency ?? state.household.currency,
      locale: locale,
    );

    final valueStyle = tabularNumberStyle(
      textTheme.displayMedium!.copyWith(fontSize: 24),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 125,
            child: _ResultCard(
              key: const Key('resultInstalmentCard'),
              label: l10n.simulatorInstalmentLabel,
              hero: true,
              valueKey: const Key('resultInstalment'),
              value: result == null ? null : money(result.totalInstalmentMinor),
              valueStyle: tabularNumberStyle(textTheme.displayLarge!),
              caption: result == null || terms == null
                  ? l10n.simulatorInstalmentEmpty
                  : l10n.simulatorInstalmentCaption(
                      money(result.monthlyPaymentMinor),
                      money(terms.insuranceMonthlyMinor),
                      terms.termMonths,
                    ),
              captionKey: const Key('resultInstalmentCaption'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 100,
            child: _ResultCard(
              key: const Key('resultCostCard'),
              label: l10n.simulatorCostLabel,
              valueKey: const Key('resultCost'),
              value: result == null ? null : money(result.totalCostMinor),
              valueStyle: valueStyle,
              caption: result == null || terms == null
                  ? l10n.simulatorCostEmpty
                  : switch (result.costOverPriceBps) {
                      final share? => l10n.simulatorCostCaption(
                        money(result.totalInterestMinor),
                        money(result.totalInsuranceMinor),
                        money(terms.upfrontFeesMinor),
                        formatBps(share, locale),
                      ),
                      null => l10n.simulatorCostCaptionNoPrice(
                        money(result.totalInterestMinor),
                        money(result.totalInsuranceMinor),
                        money(terms.upfrontFeesMinor),
                      ),
                    },
              captionKey: const Key('resultCostCaption'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 100,
            child: _ResultCard(
              key: const Key('resultTaegCard'),
              label: l10n.simulatorTaegLabel,
              // « indicatif » is always attached to the TAEG label (§15).
              labelTrailing: SimulatorMarkerPill(
                key: const Key('resultTaegIndicative'),
                label: l10n.simulatorIndicativePill,
              ),
              valueKey: const Key('resultTaeg'),
              value: result == null ? null : formatRate(result.taegBps, locale),
              valueStyle: valueStyle,
              caption: l10n.simulatorTaegCaption,
              captionKey: const Key('resultTaegCaption'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.caption,
    this.hero = false,
    this.labelTrailing,
    this.valueKey,
    this.captionKey,
  });

  final String label;

  /// `null` draws the dash: the card keeps its place before anything computes.
  final String? value;
  final TextStyle valueStyle;
  final String caption;
  final bool hero;
  final Widget? labelTrailing;
  final Key? valueKey;
  final Key? captionKey;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      gradient: hero ? AppColors.irisTintGradient : null,
      border: hero ? Border.all(color: AppColors.irisBorderStrong) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.statLabel.copyWith(
                    color: hero ? AppColors.iris : null,
                  ),
                ),
              ),
              if (labelTrailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                labelTrailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value ?? '—',
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle.copyWith(
              color: value == null
                  ? AppColors.textDisabled
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            caption,
            key: captionKey,
            style: tabularNumberStyle(
              AppTextStyles.helper,
            ).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// « Lecture HCSF » (`14-simulateur.md` §HCSF Card): the debt ratio against its
/// limit, the term against its maximum and the borrowing capacity at the
/// reference — each with its reference point, as a reading.
///
/// Over a reference only this card changes: an amber border and pill. Nothing
/// on the panel is blocked by it. With no income there is no ratio and no
/// capacity, so no gauge is drawn — the card says why and offers the way out.
class HcsfReadingCard extends StatelessWidget {
  const HcsfReadingCard({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final result = state.result;
    final hcsf = result?.hcsf;
    final over =
        hcsf != null && (hcsf.withinRatio == false || !hcsf.withinTerm);

    final Widget columns;
    if (result == null) {
      columns = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 130,
            child: _ReadingColumn(
              label: l10n.simulatorRatioLabel,
              value: null,
              valueKey: const Key('hcsfRatioValue'),
              caption: l10n.simulatorRatioEmpty,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(flex: 100, child: _TermColumn(state: state)),
          const SizedBox(width: 22),
          Expanded(
            flex: 130,
            child: _ReadingColumn(
              label: l10n.simulatorCapacityLabel,
              value: null,
              valueKey: const Key('hcsfCapacityValue'),
              caption: l10n.simulatorCapacityEmpty,
            ),
          ),
        ],
      );
    } else if (!state.incomeKnown) {
      columns = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(flex: 260, child: _UnknownIncomeBlock()),
          const SizedBox(width: 22),
          Expanded(flex: 130, child: _TermColumn(state: state)),
        ],
      );
    } else {
      columns = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 130, child: _RatioColumn(state: state)),
          const SizedBox(width: 22),
          Expanded(flex: 100, child: _TermColumn(state: state)),
          const SizedBox(width: 22),
          Expanded(flex: 130, child: _CapacityColumn(state: state)),
        ],
      );
    }

    return AppCard(
      key: const Key('hcsfCard'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      border: over ? Border.all(color: AppColors.warningBorder) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(l10n.simulatorHcsfTitle, style: textTheme.titleMedium),
              if (over) ...[
                const SizedBox(width: AppSpacing.sm + 2),
                StatusPill(
                  key: const Key('hcsfOverPill'),
                  label: l10n.simulatorHcsfOver,
                  tone: StatusPillTone.warning,
                ),
              ],
              const Spacer(),
              // Body content, never a tooltip: the app makes no lending
              // decisions and says so where the reading is shown (§15, §17).
              const Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: AppColors.textDisabled,
              ),
              const SizedBox(width: AppSpacing.xs + 1),
              Text(
                l10n.simulatorHcsfCaveat,
                key: const Key('hcsfCaveat'),
                style: AppTextStyles.helper.copyWith(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          columns,
        ],
      ),
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
    final result = state.result!;
    final household = state.household;
    final ratio = result.debtRatioBps!;
    final income = household.monthlyIncomeMinor;
    final withExisting =
        state.inputs.includeExistingLoans && household.existingChargeMinor > 0;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: result.currency,
      locale: locale,
    );

    final source = household.incomeSource == IncomeSource.declared
        ? 'declared'
        : 'ledger';

    return _ReadingColumn(
      label: l10n.simulatorRatioLabel,
      value: formatBps(ratio, locale),
      valueKey: const Key('hcsfRatioValue'),
      reference: l10n.simulatorReference(
        formatBps(result.hcsf.limitBps, locale, digits: 0),
      ),
      gauge: _ReadingGauge(
        key: const Key('hcsfRatioGauge'),
        fill: ratio / simulatorRatioScaleBps,
        tick: result.hcsf.limitBps / simulatorRatioScaleBps,
        warning: result.hcsf.withinRatio == false,
      ),
      caption: income == null
          ? null
          : withExisting
          ? l10n.simulatorRatioCaptionWithExisting(
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
      reference: hcsf == null
          ? null
          : l10n.simulatorReference(termLabel(l10n, hcsf.maxTermMonths)),
      gauge: hcsf == null
          ? null
          : _ReadingGauge(
              key: const Key('hcsfTermGauge'),
              fill: term / SimulatorInputs.maxTermMonths,
              tick: hcsf.maxTermMonths / SimulatorInputs.maxTermMonths,
              warning: !hcsf.withinTerm,
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
    final result = state.result!;
    final capacity = result.maxBorrowableMinor;
    final available = result.availableInstalmentMinor;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: result.currency,
      locale: locale,
    );

    // A small capacity is explained by its cause: when the current loans are
    // what fill the room under the reference, the caption says so.
    final crowdedByExisting =
        state.inputs.includeExistingLoans &&
        state.household.existingChargeMinor > 0 &&
        result.hcsf.withinRatio == false;

    return _ReadingColumn(
      label: l10n.simulatorCapacityLabel,
      value: capacity == null ? null : money(capacity),
      valueKey: const Key('hcsfCapacityValue'),
      caption: available == null
          ? null
          : crowdedByExisting
          ? l10n.simulatorCapacityCaptionExisting(money(available))
          : l10n.simulatorCapacityCaption(
              money(available),
              formatBps(result.hcsf.limitBps, locale, digits: 0),
            ),
      captionKey: const Key('hcsfCapacityCaption'),
    );
  }
}

class _ReadingColumn extends StatelessWidget {
  const _ReadingColumn({
    required this.label,
    required this.value,
    this.valueKey,
    this.reference,
    this.gauge,
    this.caption,
    this.captionKey,
  });

  final String label;

  /// `null` draws the dash.
  final String? value;
  final Key? valueKey;
  final String? reference;
  final Widget? gauge;
  final String? caption;
  final Key? captionKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.statLabel),
        const SizedBox(height: AppSpacing.xs + 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value ?? '—',
                key: valueKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    tabularNumberStyle(
                      textTheme.displayMedium!.copyWith(fontSize: 22),
                    ).copyWith(
                      color: value == null
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                    ),
              ),
            ),
            if (reference != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                reference!,
                style: AppTextStyles.helper.copyWith(fontSize: 12),
              ),
            ],
          ],
        ),
        if (gauge != null) ...[const SizedBox(height: AppSpacing.sm), gauge!],
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption!,
            key: captionKey,
            style: tabularNumberStyle(
              AppTextStyles.helper,
            ).copyWith(fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

/// A 6 px gauge on a fixed scale with its reference tick. Iris under the
/// reference, amber over it — the tone follows the API's `within_*` flags, not
/// a comparison made here. Past the scale the fill clamps; the printed figure
/// beside it stays exact.
class _ReadingGauge extends StatelessWidget {
  const _ReadingGauge({
    super.key,
    required this.fill,
    required this.tick,
    required this.warning,
  });

  final double fill;
  final double tick;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: AppColors.surfaceHover,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fill.clamp(0.0, 1.0),
                child: ColoredBox(
                  color: warning ? AppColors.warning : AppColors.iris,
                ),
              ),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: tick.clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionalTranslation(
                translation: const Offset(0.5, 0),
                child: Container(
                  width: 2,
                  height: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ④: ratio and capacity collapse into one block — the dash, why, and the way
/// out.
class _UnknownIncomeBlock extends StatelessWidget {
  const _UnknownIncomeBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const Key('hcsfUnknownIncome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.simulatorRatioLabel.toUpperCase(),
          style: AppTextStyles.statLabel,
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          '—',
          key: const Key('hcsfRatioValue'),
          style: textTheme.displayMedium!.copyWith(
            fontSize: 22,
            color: AppColors.textDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          l10n.simulatorRatioUnknown,
          key: const Key('hcsfUnknownIncomeText'),
          style: AppTextStyles.helper.copyWith(fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        SizedBox(
          height: 30,
          child: OutlinedButton.icon(
            key: const Key('hcsfDeclareIncome'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SimulatorIncomeModal(),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.iris,
              side: const BorderSide(color: AppColors.irisBorderStrong),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + AppSpacing.xs,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: Text(l10n.simulatorDeclareIncome),
          ),
        ),
      ],
    );
  }
}

/// « Déclarer un revenu », opened from the unknown-income reading. The income
/// becomes the ratio's denominator, and the reading recomputes behind it.
class SimulatorIncomeModal extends ConsumerStatefulWidget {
  const SimulatorIncomeModal({super.key});

  @override
  ConsumerState<SimulatorIncomeModal> createState() =>
      _SimulatorIncomeModalState();
}

class _SimulatorIncomeModalState extends ConsumerState<SimulatorIncomeModal> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).toString();
    final amount = parseMoneyMinor(_amount.text, locale);
    if (amount == null || amount <= 0) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(simulatorControllerProvider.notifier)
          .declareIncome(amount);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = AppLocalizations.of(context)!.simulatorIncomeFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency =
        ref.watch(simulatorControllerProvider).value?.household.currency ?? '';

    return AppModal(
      title: l10n.simulatorIncomeTitle,
      width: 440,
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.simulatorCancel),
        ),
        PrimaryButton(
          key: const Key('simulatorIncomeSubmit'),
          label: l10n.simulatorIncomeSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.simulatorIncomeBody,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorText != null) ...[
              InlineBanner(message: _errorText!),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.simulatorIncomeLabel,
              child: MoneyField(
                key: const Key('simulatorIncomeAmount'),
                controller: _amount,
                currency: currency,
                autofocus: true,
                validator: (value) {
                  final locale = Localizations.localeOf(context).toString();
                  final amount = parseMoneyMinor(value ?? '', locale);
                  return amount == null || amount <= 0
                      ? l10n.simulatorIncomeInvalid
                      : null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
