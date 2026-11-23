import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/loan_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/loan_summary_line.dart';
import '../../../core/widgets/loan_terms_fields.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/term_slider.dart';
import '../../../core/widgets/yearly_projection_chart.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/mortgage.dart';
import 'mortgage_labels.dart';

/// Opens the create/edit loan modal. Resolves to the saved loan, or `null` when
/// the user cancelled or deleted it.
Future<MortgageDetail?> showMortgageForm(
  BuildContext context, {
  Mortgage? initial,
}) {
  return showAppModal<MortgageDetail>(
    context: context,
    builder: (_) => MortgageFormModal(initial: initial),
  );
}

/// The « Nouveau crédit » modal (`12-credits.md` « Loan form »), laid out as
/// the Simulateur: the inputs pane on the left, its terms typed with the
/// Simulateur's own fields and term slider, and a reading pane on the right
/// (the summary line and the yearly projection) that follows every
/// keystroke. Reused prefilled for « Modifier le crédit », where the ghost
/// « Supprimer » opens its destructive confirmation.
class MortgageFormModal extends ConsumerStatefulWidget {
  const MortgageFormModal({super.key, this.initial});

  final Mortgage? initial;

  @override
  ConsumerState<MortgageFormModal> createState() => _MortgageFormModalState();
}

class _MortgageFormModalState extends ConsumerState<MortgageFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(
    text: widget.initial?.label,
  );
  late final _lenderController = TextEditingController(
    text: widget.initial?.lender,
  );
  final _principalController = TextEditingController();
  final _rateController = TextEditingController();
  final _dateController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _feesController = TextEditingController();

  late MortgageKind _kind = widget.initial?.kind ?? MortgageKind.mortgage;
  late RepaymentType _repayment =
      widget.initial?.repaymentType ?? RepaymentType.constantPayment;
  late String? _propertyId = widget.initial?.propertyId;
  late int _termMonths =
      widget.initial?.termMonths ?? LoanTermScale.defaultMonths;

  /// Guards the one-time locale-aware fill of the amount, rate and date fields,
  /// which needs the active locale and so cannot run in `initState`.
  bool _filled = false;
  bool _isSubmitting = false;
  String? _rateError;
  String? _feesError;
  String? _propertyError;
  String? _bannerError;

  /// The field values once the prefill has run, so the form reads as
  /// changed only while something differs from what it opened with.
  List<String>? _pristineTexts;
  bool _dirty = false;

  bool get _isEditing => widget.initial != null;

  List<TextEditingController> get _textInputs => [
    _labelController,
    _lenderController,
    _dateController,
    ..._computeInputs,
  ];

  List<TextEditingController> get _computeInputs => [
    _principalController,
    _rateController,
    _insuranceController,
    _feesController,
  ];

  @override
  void initState() {
    super.initState();
    // Listening starts after the first frame: the prefill writes these
    // controllers during the build, where the preview provider can't be moved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final controller in _computeInputs) {
        controller.addListener(_requestPreview);
      }
      _pristineTexts = [for (final c in _textInputs) c.text];
      for (final controller in _textInputs) {
        controller.addListener(_updateDirty);
      }
      _requestPreview();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final initial = widget.initial;
    if (initial == null) return;
    final locale = Localizations.localeOf(context).toString();
    _principalController.text = formatMoneyInput(
      initial.principalMinor,
      locale,
    );
    _rateController.text = formatRateInput(initial.annualRateBps, locale);
    _dateController.text = appDateFormat(
      locale,
    ).format(initial.firstPaymentDate);
    if (initial.insuranceMonthlyMinor > 0) {
      _insuranceController.text = formatMoneyInput(
        initial.insuranceMonthlyMinor,
        locale,
      );
    }
    if (initial.upfrontFeesMinor > 0) {
      _feesController.text = formatMoneyInput(initial.upfrontFeesMinor, locale);
    }
  }

  @override
  void dispose() {
    for (final controller in _textInputs) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Whether the form holds unsaved input: the frame then asks before
  /// closing it (`00` §7 « Modal », Closing).
  void _updateDirty() {
    if (!mounted) return;
    final pristine = _pristineTexts;
    final initial = widget.initial;
    final textsChanged =
        pristine != null &&
        [
          for (final (i, c) in _textInputs.indexed) c.text != pristine[i],
        ].any((changed) => changed);
    final dirty =
        textsChanged ||
        _kind != (initial?.kind ?? MortgageKind.mortgage) ||
        _repayment !=
            (initial?.repaymentType ?? RepaymentType.constantPayment) ||
        _propertyId != initial?.propertyId ||
        _termMonths != (initial?.termMonths ?? LoanTermScale.defaultMonths);
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  String get _locale => Localizations.localeOf(context).toString();

  /// An optional amount: empty is zero, anything else must read as one.
  int? _optionalMoney(String text) =>
      text.trim().isEmpty ? 0 : parseMoneyMinor(text, _locale);

  /// Asks for a fresh reading once the inputs describe a loan the simulator
  /// can run. An in-fine loan is not one of those — `/simulations/compute`
  /// only knows constant payments — so the reading pane says so rather than
  /// showing a figure that would be wrong.
  void _requestPreview() {
    if (!mounted) return;
    final preview = ref.read(loanInstalmentPreviewProvider.notifier);
    final principal = parseMoneyMinor(_principalController.text, _locale);
    final rate = parseRateBps(_rateController.text);
    final term = _termMonths;
    final insurance = _optionalMoney(_insuranceController.text);
    final fees = _optionalMoney(_feesController.text);

    if (_repayment == RepaymentType.interestOnly ||
        principal == null ||
        principal <= 0 ||
        rate == null ||
        term <= 0 ||
        insurance == null ||
        fees == null) {
      preview.clear();
      return;
    }
    preview.request(
      principalMinor: principal,
      annualRateBps: rate,
      insuranceMonthlyMinor: insurance,
      termMonths: term,
      upfrontFeesMinor: fees,
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    final firstPayment = parseDateInput(_dateController.text, _locale);
    final draft = LoanDraft(
      label: _labelController.text.trim(),
      lender: _lenderController.text.trim(),
      kind: _kind,
      repaymentType: _repayment,
      principalMinor: parseMoneyMinor(_principalController.text, _locale)!,
      annualRateBps: parseRateBps(_rateController.text)!,
      insuranceMonthlyMinor: _optionalMoney(_insuranceController.text)!,
      termMonths: _termMonths,
      firstPaymentDate: firstPayment!,
      upfrontFeesMinor: _optionalMoney(_feesController.text)!,
      propertyId: _propertyId,
    );

    setState(() {
      _isSubmitting = true;
      _rateError = _feesError = _propertyError = _bannerError = null;
    });

    final controller = ref.read(mortgagesControllerProvider.notifier);
    try {
      final saved = _isEditing
          ? await controller.updateLoan(widget.initial!.id, draft)
          : await controller.create(draft);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      // A refused number is explained under that number: the user has to change
      // it, and it is on screen.
      final message = localizeMortgageError(l10n, error);
      setState(() {
        _isSubmitting = false;
        switch (mortgageErrorField(error)) {
          case MortgageErrorField.rate:
            _rateError = message;
          case MortgageErrorField.fees:
            _feesError = message;
          case MortgageErrorField.property:
            _propertyError = message;
          case MortgageErrorField.none:
            _bannerError = message;
        }
      });
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppModal<bool>(
      context: context,
      builder: (dialogContext) => AppModal(
        title: l10n.mortgageDeleteTitle(widget.initial!.label),
        width: AppModalSizes.w440,
        kind: AppModalKind.destructive,
        // What leaves (the Synthèse deduction, the schedule) and what stays
        // (the accounts), as the lead; a confirmation has no body.
        subtitle: Text(
          l10n.mortgageDeleteBody,
          key: const Key('mortgageDeleteBody'),
        ),
        actions: [
          const AppModalCancel(),
          AppButton(
            key: const Key('mortgageDeleteConfirm'),
            label: l10n.mortgageDeleteConfirm,
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _bannerError = null;
    });
    try {
      await ref
          .read(mortgagesControllerProvider.notifier)
          .archive(widget.initial!.id);
      ref.read(selectedMortgageProvider.notifier).close();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _bannerError = localizeMortgageError(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency =
        ref.watch(mortgagesControllerProvider).value?.summary.currency ??
        widget.initial?.currency ??
        '';
    final properties =
        ref.watch(loanPropertiesProvider).value ?? const <LoanProperty>[];
    final preview = ref.watch(loanInstalmentPreviewProvider);
    final interestOnly = _repayment == RepaymentType.interestOnly;
    const rowGap = SizedBox(height: AppSpacing.fieldGap);

    // A refused preview is explained where the save's refusal would be: under
    // the rate or the fees when one of them is the cause, otherwise above the
    // reading (the Simulateur's arrangement).
    final previewError = interestOnly ? null : preview?.error;
    final previewField = mortgageErrorField(previewError);
    final previewMessage = previewError == null
        ? null
        : localizeMortgageError(l10n, previewError);

    final inputs = Column(
      key: const Key('mortgageFormInputs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LabeledField(
          label: l10n.mortgageFormLabel,
          child: TextFormField(
            key: const Key('mortgageFormLabel'),
            controller: _labelController,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? l10n.mortgageFormLabelRequired
                : null,
          ),
        ),
        rowGap,
        ModalFieldRow(
          start: ModalFieldCell(
            label: l10n.mortgageFormLender,
            input: TextFormField(
              key: const Key('mortgageFormLender'),
              controller: _lenderController,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.mortgageFormLenderRequired
                  : null,
            ),
          ),
          end: ModalFieldCell(
            label: l10n.mortgageFormFirstPayment,
            input: DateField(
              key: const Key('mortgageFormFirstPayment'),
              controller: _dateController,
              firstDate: DateTime(1970),
              lastDate: DateTime(2100),
              calendarTooltip: l10n.mortgageFormCalendar,
              validator: (value) => parseDateInput(value ?? '', _locale) == null
                  ? l10n.mortgageFormDateInvalid
                  : null,
            ),
          ),
        ),
        rowGap,
        // The two selects take the full width: their French values (« Crédit
        // à la consommation », « Échéance constante ») would not fit a column
        // of the Simulateur's pane.
        LabeledField(
          label: l10n.mortgageFormKind,
          child: AppSelect<MortgageKind>(
            key: const Key('mortgageFormKind'),
            value: _kind,
            // The product label only — it never touches the repayment type.
            onChanged: (value) {
              setState(() => _kind = value);
              _updateDirty();
            },
            items: [
              for (final kind in MortgageKind.values)
                AppSelectItem(
                  value: kind,
                  label: mortgageKindLabel(l10n, kind),
                ),
            ],
          ),
        ),
        rowGap,
        LabeledField(
          label: l10n.mortgageFormRepayment,
          child: AppSelect<RepaymentType>(
            key: const Key('mortgageFormRepayment'),
            value: _repayment,
            onChanged: (value) {
              setState(() => _repayment = value);
              _updateDirty();
              _requestPreview();
            },
            items: [
              for (final type in RepaymentType.values)
                AppSelectItem(
                  value: type,
                  label: repaymentTypeLabel(l10n, type),
                ),
            ],
          ),
        ),
        rowGap,
        // The terms, typed exactly as in the Simulateur.
        LoanTermsFields(
          currency: currency,
          gutter: AppModalSizes.columnGutter,
          rowGap: AppSpacing.fieldGap,
          fees: LoanTermsInput(
            key: const Key('mortgageFormFees'),
            controller: _feesController,
            label: l10n.mortgageFormFees,
            errorText:
                _feesError ??
                (previewField == MortgageErrorField.fees
                    ? previewMessage
                    : null),
            validator: (value) => _optionalMoney(value ?? '') == null
                ? l10n.mortgageFormAmountOptionalInvalid
                : null,
          ),
          principal: LoanTermsInput(
            key: const Key('mortgageFormPrincipal'),
            controller: _principalController,
            label: l10n.mortgageFormPrincipal,
            validator: (value) {
              final amount = parseMoneyMinor(value ?? '', _locale);
              return amount == null || amount <= 0
                  ? l10n.mortgageFormAmountInvalid
                  : null;
            },
          ),
          rate: LoanTermsInput(
            key: const Key('mortgageFormRate'),
            controller: _rateController,
            label: l10n.mortgageFormRate,
            errorText:
                _rateError ??
                (previewField == MortgageErrorField.rate
                    ? previewMessage
                    : null),
            validator: (value) => parseRateBps(value ?? '') == null
                ? l10n.mortgageFormRateInvalid
                : null,
          ),
          insurance: LoanTermsInput(
            key: const Key('mortgageFormInsurance'),
            controller: _insuranceController,
            label: l10n.mortgageFormInsurance,
            validator: (value) => _optionalMoney(value ?? '') == null
                ? l10n.mortgageFormAmountOptionalInvalid
                : null,
          ),
          term: TermSlider(
            termMonths: _termMonths,
            minMonths: LoanTermScale.minMonths,
            maxMonths: LoanTermScale.maxMonths,
            stepMonths: LoanTermScale.stepMonths,
            sliderKey: const Key('mortgageFormTerm'),
            valueKey: const Key('mortgageFormTermValue'),
            onChanged: (months) {
              setState(() => _termMonths = months);
              _updateDirty();
              _requestPreview();
            },
          ),
        ),
        // Without a property to link there is nothing to pick: the field
        // stays away rather than offering « Aucun » alone.
        if (properties.isNotEmpty || _propertyId != null) ...[
          rowGap,
          LabeledField(
            label: l10n.mortgageFormProperty,
            errorText: _propertyError,
            child: AppSelect<String?>(
              key: const Key('mortgageFormProperty'),
              value: _propertyId,
              onChanged: (value) {
                setState(() => _propertyId = value);
                _updateDirty();
              },
              items: [
                // An existing link cannot be cleared through the API (null
                // means "absent" on a patch), so « Aucun » is only offered
                // while nothing is linked.
                if (widget.initial?.propertyId == null)
                  AppSelectItem<String?>(
                    value: null,
                    label: l10n.mortgageFormPropertyNone,
                  ),
                for (final property in properties)
                  AppSelectItem<String?>(
                    value: property.id,
                    label: property.label,
                    subtitle: property.address,
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    final computed = interestOnly ? null : preview?.value;
    final reading = Column(
      key: const Key('mortgageFormReading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (previewMessage != null &&
            previewField == MortgageErrorField.none) ...[
          InlineBanner(
            key: const Key('mortgageFormPreviewError'),
            message: previewMessage,
          ),
          const SizedBox(height: AppSimulator.readingGap),
        ],
        LoanSummaryLine(
          key: const Key('mortgageFormSummary'),
          captionMaxLines: 3,
          currency: computed?.currency ?? currency,
          emptyCaption: interestOnly
              ? l10n.mortgageFormInterestOnly
              : l10n.mortgageFormInstalmentEmpty,
          figures: computed == null
              ? null
              : (
                  totalInstalmentMinor: computed.totalInstalmentMinor,
                  monthlyPaymentMinor: computed.monthlyPaymentMinor,
                  insuranceMonthlyMinor: computed.insuranceMonthlyMinor,
                  termMonths: computed.termMonths,
                  totalCostMinor: computed.totalCostMinor,
                  totalInterestMinor: computed.totalInterestMinor,
                  totalInsuranceMinor: computed.totalInsuranceMinor,
                  upfrontFeesMinor: computed.upfrontFeesMinor,
                  taegBps: computed.taegBps,
                ),
        ),
        const SizedBox(height: AppSimulator.readingGap / 2),
        Divider(height: 1, thickness: 1, color: context.colors.line),
        const SizedBox(height: AppSimulator.readingGap / 2),
        SizedBox(
          height: AppLoans.formChartHeight,
          child: YearlyProjection(
            currency: computed?.currency ?? currency,
            emptyText: interestOnly
                ? l10n.mortgageFormChartInterestOnly
                : l10n.mortgageFormChartEmpty,
            years: computed == null
                ? null
                : [
                    for (final row in computed.yearly)
                      (
                        year: row.year,
                        capitalMinor: row.principalMinor,
                        interestMinor: row.interestMinor,
                      ),
                  ],
          ),
        ),
      ],
    );

    return AppModal(
      title: _isEditing
          ? l10n.mortgageFormEditTitle
          : l10n.mortgageFormCreateTitle,
      width: AppModalSizes.w960,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _bannerError,
      onSubmit: _submit,
      leadingAction: _isEditing
          ? AppButton(
              key: const Key('mortgageFormDelete'),
              label: l10n.mortgageFormDelete,
              variant: AppButtonVariant.ghost,
              onPressed: _delete,
            )
          : null,
      actions: [
        const AppModalCancel(key: Key('mortgageFormCancel')),
        PrimaryButton(
          key: const Key('mortgageFormSubmit'),
          label: l10n.mortgageFormSave,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        // The Simulateur's two panes inside the modal body: the hairline runs
        // the full height of the taller one.
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: AppLoans.formInputsWidth, child: inputs),
                const SizedBox(
                  width: AppLoans.formInputsGap + 1 + AppLoans.formReadingGap,
                ),
                Expanded(child: reading),
              ],
            ),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: AppLoans.formInputsWidth + AppLoans.formInputsGap,
              child: SizedBox(
                width: 1,
                child: ColoredBox(color: context.colors.line),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
