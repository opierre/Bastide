import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_slider.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';
import 'simulator_labels.dart';

/// « Nouveau crédit » (`14-simulateur.md` §Form Card): the inputs, the term
/// slider and the existing-loans switch.
///
/// Each edit goes straight to the controller, which debounces the compute; the
/// text controllers here only hold what is being typed. The one figure written
/// back into a field is the derived borrowed amount, and only while it is
/// still derived — never under the user's cursor.
class SimulatorForm extends ConsumerStatefulWidget {
  const SimulatorForm({super.key, required this.state});

  final SimulatorState state;

  @override
  ConsumerState<SimulatorForm> createState() => _SimulatorFormState();
}

class _SimulatorFormState extends ConsumerState<SimulatorForm> {
  final _price = TextEditingController();
  final _downPayment = TextEditingController();
  final _fees = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _insurance = TextEditingController();

  /// Guards the one-time fill from the controller's inputs, which needs the
  /// locale — the panel may be reopened over inputs typed earlier.
  bool _filled = false;
  bool _rateUnreadable = false;

  String get _locale => Localizations.localeOf(context).toString();

  SimulatorController get _controller =>
      ref.read(simulatorControllerProvider.notifier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final inputs = widget.state.inputs;
    void fill(TextEditingController controller, int? minor) {
      if (minor != null) controller.text = formatMoneyInput(minor, _locale);
    }

    fill(_price, inputs.propertyPriceMinor);
    fill(_downPayment, inputs.downPaymentMinor);
    fill(_fees, inputs.upfrontFeesMinor);
    fill(_principal, inputs.principalMinor);
    fill(_insurance, inputs.insuranceMonthlyMinor);
    if (inputs.annualRateBps case final bps?) {
      final separator = NumberFormat.decimalPattern(
        _locale,
      ).symbols.DECIMAL_SEP;
      _rate.text =
          '${bps ~/ 100}$separator${(bps % 100).toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _price,
      _downPayment,
      _fees,
      _principal,
      _rate,
      _insurance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _money(String text) => parseMoneyMinor(text, _locale);

  void _onRateChanged(String text) {
    final bps = parseRateBps(text);
    setState(() => _rateUnreadable = text.trim().isNotEmpty && bps == null);
    _controller.setRate(bps);
  }

  Widget _pair(Widget first, Widget second) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: 14),
      Expanded(child: second),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;
    final inputs = state.inputs;
    final currency = state.household.currency;
    final hint = NumberFormat.decimalPatternDigits(
      locale: _locale,
      decimalDigits: 2,
    ).format(0);

    // The derived amount follows price, fees and down payment into its field.
    ref.listen<AsyncValue<SimulatorState>>(simulatorControllerProvider, (
      _,
      next,
    ) {
      final value = next.value;
      if (value == null || !value.principalDerived) return;
      final minor = value.inputs.principalMinor;
      final text = minor == null ? '' : formatMoneyInput(minor, _locale);
      if (_principal.text != text) _principal.text = text;
    });

    final errorField = simulatorErrorField(state.computeError);
    final errorMessage = localizeSimulatorError(l10n, state.computeError);
    const rowGap = SizedBox(height: 12);

    return AppCard(
      key: const Key('simulatorForm'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.simulatorFormTitle, style: textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            l10n.simulatorFormSubtitle,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _pair(
            LabeledField(
              label: l10n.simulatorPrice,
              child: MoneyField(
                key: const Key('simulatorPrice'),
                controller: _price,
                currency: currency,
                autofocus: true,
                hintText: hint,
                onChanged: (text) => _controller.setPropertyPrice(_money(text)),
              ),
            ),
            LabeledField(
              label: l10n.simulatorDownPayment,
              child: MoneyField(
                key: const Key('simulatorDownPayment'),
                controller: _downPayment,
                currency: currency,
                hintText: hint,
                onChanged: (text) => _controller.setDownPayment(_money(text)),
              ),
            ),
          ),
          rowGap,
          _pair(
            LabeledField(
              label: l10n.simulatorFees,
              errorText: errorField == SimulatorErrorField.fees
                  ? errorMessage
                  : null,
              child: MoneyField(
                key: const Key('simulatorFees'),
                controller: _fees,
                currency: currency,
                hintText: hint,
                onChanged: (text) => _controller.setFees(_money(text)),
              ),
            ),
            LabeledField(
              label: l10n.simulatorPrincipal,
              // A convenience, not a constraint: the pill says the figure was
              // filled in, and editing it takes it over.
              trailing: state.principalDerived && inputs.principalMinor != null
                  ? SimulatorMarkerPill(
                      key: const Key('simulatorDerivedPill'),
                      label: l10n.simulatorDerivedPill,
                      neutral: true,
                    )
                  : null,
              child: MoneyField(
                key: const Key('simulatorPrincipal'),
                controller: _principal,
                currency: currency,
                hintText: hint,
                onChanged: (text) => _controller.setPrincipal(_money(text)),
              ),
            ),
          ),
          rowGap,
          _pair(
            LabeledField(
              label: l10n.simulatorRate,
              errorText: _rateUnreadable
                  ? l10n.simulatorRateInvalid
                  : errorField == SimulatorErrorField.rate
                  ? errorMessage
                  : null,
              child: TextFormField(
                key: const Key('simulatorRate'),
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.right,
                style: tabularNumberStyle(textTheme.bodyLarge!),
                decoration: InputDecoration(
                  hintText: '—',
                  suffixText: '%',
                  suffixStyle: fieldSuffixStyle(context),
                ),
                onChanged: _onRateChanged,
              ),
            ),
            LabeledField(
              label: l10n.simulatorInsurance,
              child: MoneyField(
                key: const Key('simulatorInsurance'),
                controller: _insurance,
                currency: currency,
                hintText: hint,
                onChanged: (text) => _controller.setInsurance(_money(text)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _TermSlider(termMonths: inputs.termMonths),
          const SizedBox(height: AppSpacing.md),
          _ExistingLoansSwitch(state: state),
        ],
      ),
    );
  }
}

/// The Phase 2 slider over 5–30 years, a year at a time, labelled in both
/// units so neither has to be converted in the head.
class _TermSlider extends ConsumerWidget {
  const _TermSlider({required this.termMonths});

  final int termMonths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final bounds = AppTextStyles.helper.copyWith(
      fontSize: 11,
      color: AppColors.textDisabled,
    );
    String value(int months) => l10n.simulatorTermValue(months, months ~/ 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.simulatorTerm,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value(termMonths),
              key: const Key('simulatorTermValue'),
              style: tabularNumberStyle(
                textTheme.bodyMedium!,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        AppSlider(
          key: const Key('simulatorTermSlider'),
          value: termMonths.toDouble(),
          min: SimulatorInputs.minTermMonths.toDouble(),
          max: SimulatorInputs.maxTermMonths.toDouble(),
          divisions:
              (SimulatorInputs.maxTermMonths - SimulatorInputs.minTermMonths) ~/
              SimulatorInputs.termStepMonths,
          width: double.infinity,
          semanticFormatter: (months) => value(months.round()),
          onChanged: (months) => ref
              .read(simulatorControllerProvider.notifier)
              .setTerm(months.round()),
        ),
        Row(
          children: [
            Text(termLabel(l10n, SimulatorInputs.minTermMonths), style: bounds),
            const Spacer(),
            Text(termLabel(l10n, SimulatorInputs.maxTermMonths), style: bounds),
          ],
        ),
      ],
    );
  }
}

/// « Inclure mes crédits actuels », with a sub-line naming exactly what turning
/// it on adds to the reading.
class _ExistingLoansSwitch extends ConsumerWidget {
  const _ExistingLoansSwitch({required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final household = state.household;
    final charge = household.existingChargeMinor;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.simulatorIncludeExisting,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                charge > 0
                    ? l10n.simulatorIncludeExistingAdds(
                        formatAmount(
                          amountMinor: charge,
                          currency: household.currency,
                          locale: locale,
                        ),
                      )
                    : l10n.simulatorIncludeExistingNone,
                key: const Key('simulatorIncludeExistingSub'),
                style: AppTextStyles.helper,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppToggle(
          key: const Key('simulatorIncludeExisting'),
          value: state.inputs.includeExistingLoans,
          semanticLabel: l10n.simulatorIncludeExisting,
          onChanged: ref
              .read(simulatorControllerProvider.notifier)
              .setIncludeExistingLoans,
        ),
      ],
    );
  }
}
