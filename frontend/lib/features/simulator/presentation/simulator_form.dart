import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/loan_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/loan_terms_fields.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/term_slider.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';
import 'simulator_labels.dart';

/// The top of the inputs pane (`14-simulateur.md` §Inputs pane): « Nouveau
/// crédit », the two-column field grid, the term slider and the existing-loans
/// toggle, 14 px apart.
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
      _rate.text = formatRateInput(bps, _locale);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;
    final inputs = state.inputs;
    final currency = state.household.currency;
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
    const blockGap = SizedBox(height: AppSimulator.inputsGap);

    return KeyedSubtree(
      key: const Key('simulatorForm'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.simulatorFormTitle, style: textTheme.titleSmall),
          blockGap,
          LoanTermsFields(
            currency: currency,
            leading: (
              LoanTermsInput(
                key: const Key('simulatorPrice'),
                controller: _price,
                label: l10n.simulatorPrice,
                autofocus: true,
                onChanged: (text) => _controller.setPropertyPrice(_money(text)),
              ),
              LoanTermsInput(
                key: const Key('simulatorDownPayment'),
                controller: _downPayment,
                label: l10n.simulatorDownPayment,
                onChanged: (text) => _controller.setDownPayment(_money(text)),
              ),
            ),
            fees: LoanTermsInput(
              key: const Key('simulatorFees'),
              controller: _fees,
              label: l10n.simulatorFees,
              errorText: errorField == SimulatorErrorField.fees
                  ? errorMessage
                  : null,
              onChanged: (text) => _controller.setFees(_money(text)),
            ),
            principal: LoanTermsInput(
              key: const Key('simulatorPrincipal'),
              controller: _principal,
              label: l10n.simulatorPrincipal,
              // A convenience, not a constraint: the helper says the figure
              // was filled in, and editing it takes it over.
              helper: state.principalDerived && inputs.principalMinor != null
                  ? l10n.simulatorPrincipalDerivedHelper
                  : null,
              onChanged: (text) => _controller.setPrincipal(_money(text)),
            ),
            rate: LoanTermsInput(
              key: const Key('simulatorRate'),
              controller: _rate,
              label: l10n.simulatorRate,
              errorText: _rateUnreadable
                  ? l10n.simulatorRateInvalid
                  : errorField == SimulatorErrorField.rate
                  ? errorMessage
                  : null,
              onChanged: _onRateChanged,
            ),
            insurance: LoanTermsInput(
              key: const Key('simulatorInsurance'),
              controller: _insurance,
              label: l10n.simulatorInsurance,
              onChanged: (text) => _controller.setInsurance(_money(text)),
            ),
            // A year at a time over 5–30 years (§Inputs pane, 3).
            term: TermSlider(
              termMonths: inputs.termMonths,
              minMonths: SimulatorInputs.minTermMonths,
              maxMonths: SimulatorInputs.maxTermMonths,
              stepMonths: SimulatorInputs.termStepMonths,
              sliderKey: const Key('simulatorTermSlider'),
              valueKey: const Key('simulatorTermValue'),
              onChanged: _controller.setTerm,
            ),
          ),
          blockGap,
          _ExistingLoansSwitch(state: state),
        ],
      ),
    );
  }
}

/// The toggle row: « Inclure mes crédits actuels » over the sub-line naming
/// what turning it on adds to the reading, 12 `textTertiary`.
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
        AppToggle(
          key: const Key('simulatorIncludeExisting'),
          value: state.inputs.includeExistingLoans,
          semanticLabel: l10n.simulatorIncludeExisting,
          onChanged: ref
              .read(simulatorControllerProvider.notifier)
              .setIncludeExistingLoans,
        ),
        const SizedBox(width: AppSpacing.smPlus),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.simulatorIncludeExisting,
                style: Theme.of(context).textTheme.bodyMedium,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
