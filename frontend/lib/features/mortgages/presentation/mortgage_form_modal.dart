import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
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

/// Reads a typed percent as basis points — « 3,45 » → 345.
///
/// The one place a rate changes unit (rates are bps).
/// Done on the digits rather than through a double, so 3,45 can never come out
/// as 344. Accepts a comma or a point, at most two decimals.
int? parseRateBps(String raw) {
  final match = RegExp(r'^\s*(\d{1,3})(?:[.,](\d{0,2}))?\s*$').firstMatch(raw);
  if (match == null) return null;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return int.parse(match.group(1)!) * 100 + int.parse(fraction);
}

/// The inverse, for prefilling the rate field in the locale's own spelling.
String formatRateInput(int bps, String locale) {
  final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  return '${bps ~/ 100}$separator${(bps % 100).toString().padLeft(2, '0')}';
}

/// The 600 px « Nouveau crédit » modal (`12-credits.md` « Loan form »,
/// `proposal_v6` m-loans), reused prefilled for « Modifier le crédit », where
/// the ghost « Supprimer » opens its destructive confirmation.
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
  late final _termController = TextEditingController(
    text: widget.initial?.termMonths.toString(),
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
    _termController,
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
        _propertyId != initial?.propertyId;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  String get _locale => Localizations.localeOf(context).toString();

  /// An optional amount: empty is zero, anything else must read as one.
  int? _optionalMoney(String text) =>
      text.trim().isEmpty ? 0 : parseMoneyMinor(text, _locale);

  /// Asks for a fresh plate once the inputs describe a loan the simulator can
  /// run. An in-fine loan is not one of those — `/simulations/compute` only
  /// knows constant payments — so its plate says so rather than showing a
  /// figure that would be wrong.
  void _requestPreview() {
    if (!mounted) return;
    final preview = ref.read(loanInstalmentPreviewProvider.notifier);
    final principal = parseMoneyMinor(_principalController.text, _locale);
    final rate = parseRateBps(_rateController.text);
    final term = int.tryParse(_termController.text.trim());
    final insurance = _optionalMoney(_insuranceController.text);
    final fees = _optionalMoney(_feesController.text);

    if (_repayment == RepaymentType.interestOnly ||
        principal == null ||
        principal <= 0 ||
        rate == null ||
        term == null ||
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
      termMonths: int.parse(_termController.text.trim()),
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
    final numberStyle = tabularNumberStyle(
      Theme.of(context).textTheme.bodyLarge!,
    );
    final currency =
        ref.watch(mortgagesControllerProvider).value?.summary.currency ??
        widget.initial?.currency ??
        '';
    final properties =
        ref.watch(loanPropertiesProvider).value ?? const <LoanProperty>[];
    final preview = ref.watch(loanInstalmentPreviewProvider);
    const rowGap = SizedBox(height: AppSpacing.fieldGap);

    final feesCell = ModalFieldCell(
      label: l10n.mortgageFormFees,
      errorText: _feesError,
      input: MoneyField(
        key: const Key('mortgageFormFees'),
        controller: _feesController,
        currency: currency,
        validator: (value) => _optionalMoney(value ?? '') == null
            ? l10n.mortgageFormAmountOptionalInvalid
            : null,
      ),
    );
    // Without a property to link, Frais de dossier stays alone on the last
    // row: the one row allowed an empty cell.
    final propertyCell = (properties.isNotEmpty || _propertyId != null)
        ? ModalFieldCell(
            label: l10n.mortgageFormProperty,
            errorText: _propertyError,
            input: AppSelect<String?>(
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
          )
        : null;

    return AppModal(
      title: _isEditing
          ? l10n.mortgageFormEditTitle
          : l10n.mortgageFormCreateTitle,
      width: AppModalSizes.w600,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                label: l10n.mortgageFormKind,
                input: AppSelect<MortgageKind>(
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
            ),
            rowGap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.mortgageFormRepayment,
                input: AppSelect<RepaymentType>(
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
              end: ModalFieldCell(
                label: l10n.mortgageFormPrincipal,
                input: MoneyField(
                  key: const Key('mortgageFormPrincipal'),
                  controller: _principalController,
                  currency: currency,
                  validator: (value) {
                    final amount = parseMoneyMinor(value ?? '', _locale);
                    return amount == null || amount <= 0
                        ? l10n.mortgageFormAmountInvalid
                        : null;
                  },
                ),
              ),
            ),
            rowGap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.mortgageFormRate,
                errorText: _rateError,
                input: TextFormField(
                  key: const Key('mortgageFormRate'),
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textAlign: TextAlign.right,
                  style: numberStyle,
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: fieldSuffixStyle(context),
                  ),
                  validator: (value) => parseRateBps(value ?? '') == null
                      ? l10n.mortgageFormRateInvalid
                      : null,
                ),
              ),
              end: ModalFieldCell(
                label: l10n.mortgageFormTerm,
                input: TextFormField(
                  key: const Key('mortgageFormTerm'),
                  controller: _termController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.right,
                  style: numberStyle,
                  decoration: InputDecoration(
                    suffixText: l10n.mortgageFormTermUnit,
                    suffixStyle: fieldSuffixStyle(context),
                  ),
                  validator: (value) {
                    final term = int.tryParse(value?.trim() ?? '');
                    return term == null || term <= 0
                        ? l10n.mortgageFormTermInvalid
                        : null;
                  },
                ),
              ),
            ),
            rowGap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.mortgageFormFirstPayment,
                input: DateField(
                  key: const Key('mortgageFormFirstPayment'),
                  controller: _dateController,
                  firstDate: DateTime(1970),
                  lastDate: DateTime(2100),
                  calendarTooltip: l10n.mortgageFormCalendar,
                  validator: (value) =>
                      parseDateInput(value ?? '', _locale) == null
                      ? l10n.mortgageFormDateInvalid
                      : null,
                ),
              ),
              end: ModalFieldCell(
                label: l10n.mortgageFormInsurance,
                input: MoneyField(
                  key: const Key('mortgageFormInsurance'),
                  controller: _insuranceController,
                  currency: currency,
                  validator: (value) => _optionalMoney(value ?? '') == null
                      ? l10n.mortgageFormAmountOptionalInvalid
                      : null,
                ),
              ),
            ),
            rowGap,
            if (propertyCell != null)
              ModalFieldRow(start: feesCell, end: propertyCell)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabeledField(
                      label: feesCell.label,
                      errorText: feesCell.errorText,
                      child: feesCell.input,
                    ),
                  ),
                  const SizedBox(width: AppModalSizes.columnGutter),
                  const Spacer(),
                ],
              ),
            const SizedBox(
              height: AppSpacing.fieldGap + AppLoans.instalmentLineTop,
            ),
            _InstalmentLine(
              interestOnly: _repayment == RepaymentType.interestOnly,
              preview: preview,
            ),
          ],
        ),
      ),
    );
  }
}

/// The read-only « Mensualité calculée » line under the grid, following the
/// fields live: the label at 13/600, then on its baseline « échéance totale
/// {x} · intérêts totaux {y} » in `textSecondary` (`proposal_v6` m-loans).
/// Until the simulator can run, the same place says what it is waiting for.
/// No box, no plate.
class _InstalmentLine extends StatelessWidget {
  const _InstalmentLine({required this.interestOnly, required this.preview});

  final bool interestOnly;
  final AsyncValue<ComputedInstalment>? preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final strong = tabularNumberStyle(
      textTheme.titleSmall!,
    ).copyWith(color: colors.text);
    final secondary = tabularNumberStyle(
      textTheme.bodyMedium!,
    ).copyWith(color: colors.textSecondary);

    String money(int minor, String currency) =>
        formatAmount(amountMinor: minor, currency: currency, locale: locale);

    final Widget detail;
    if (interestOnly) {
      detail = Text(
        l10n.mortgageFormPlateInterestOnly,
        key: const Key('mortgageFormPlateInterestOnly'),
        style: secondary,
      );
    } else {
      detail = switch (preview) {
        AsyncData(:final value) => Text(
          l10n.mortgageFormPlateDetail(
            money(value.totalInstalmentMinor, value.currency),
            money(value.totalInterestMinor, value.currency),
          ),
          key: const Key('mortgageFormPlateDetail'),
          style: secondary,
        ),
        AsyncError(:final error) => Text(
          localizeMortgageError(l10n, error),
          key: const Key('mortgageFormPlateError'),
          style: secondary.copyWith(color: colors.negative),
        ),
        _ => Text(
          l10n.mortgageFormPlatePending,
          key: const Key('mortgageFormPlatePending'),
          style: secondary,
        ),
      };
    }

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(l10n.mortgageFormPlateLabel, style: strong),
        const SizedBox(width: AppLoans.instalmentLabelGap),
        Expanded(child: detail),
      ],
    );

    return KeyedSubtree(key: const Key('mortgageFormPlate'), child: content);
  }
}
