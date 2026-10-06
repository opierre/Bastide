import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/monogram_avatar.dart';
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
  return showDialog<MortgageDetail>(
    context: context,
    builder: (_) => MortgageFormModal(initial: initial),
  );
}

/// Reads a typed percent as basis points — « 3,45 » → 345.
///
/// The one place a rate changes unit (`PROJECT.md` §4: rates are bps).
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

/// The 600 px « Nouveau crédit » modal (`12-credits.md` frame ③), reused
/// prefilled for « Modifier », where deletion also lives.
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

  bool get _isEditing => widget.initial != null;

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
    for (final controller in [
      _labelController,
      _lenderController,
      _dateController,
      ..._computeInputs,
    ]) {
      controller.dispose();
    }
    super.dispose();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppModal(
        title: l10n.mortgageDeleteTitle,
        width: 440,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.mortgageFormCancel),
          ),
          FilledButton(
            key: const Key('mortgageDeleteConfirm'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: AppColors.negativeInk,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.mortgageDeleteConfirm),
          ),
        ],
        // Both consequences, named: the loan leaves Synthèse's passif, and the
        // IFI base when it was linked to a property.
        child: Text(
          l10n.mortgageDeleteBody,
          key: const Key('mortgageDeleteBody'),
          style: Theme.of(
            dialogContext,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
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
    const rowGap = SizedBox(height: 12);

    return AppModal(
      title: _isEditing
          ? l10n.mortgageFormEditTitle
          : l10n.mortgageFormCreateTitle,
      subtitle: Text(
        l10n.mortgageFormSubtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      width: 600,
      actions: [
        if (_isEditing)
          TextButton(
            key: const Key('mortgageFormDelete'),
            onPressed: _isSubmitting ? null : _delete,
            child: Text(l10n.mortgageFormDelete),
          ),
        OutlinedButton(
          key: const Key('mortgageFormCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.mortgageFormCancel),
        ),
        PrimaryButton(
          key: const Key('mortgageFormSubmit'),
          label: _isEditing ? l10n.mortgageFormSave : l10n.mortgageFormSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_bannerError != null) ...[
              InlineBanner(
                key: const Key('mortgageFormError'),
                message: _bannerError!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.mortgageFormLabel,
              child: TextFormField(
                key: const Key('mortgageFormLabel'),
                controller: _labelController,
                autofocus: true,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.mortgageFormLabelRequired
                    : null,
              ),
            ),
            rowGap,
            _pair(
              LabeledField(
                label: l10n.mortgageFormLender,
                child: TextFormField(
                  key: const Key('mortgageFormLender'),
                  controller: _lenderController,
                  // Rebuilds the monogram as the name is typed.
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 8),
                      child: MonogramAvatar(
                        name: _lenderController.text,
                        size: 24,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.mortgageFormLenderRequired
                      : null,
                ),
              ),
              LabeledField(
                label: l10n.mortgageFormKind,
                child: AppSelect<MortgageKind>(
                  key: const Key('mortgageFormKind'),
                  value: _kind,
                  // The product label only — it never touches the repayment type.
                  onChanged: (value) => setState(() => _kind = value),
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
            LabeledField(
              label: l10n.mortgageFormRepayment,
              child: AppSegmented<RepaymentType>(
                value: _repayment,
                onChanged: (value) {
                  setState(() => _repayment = value);
                  _requestPreview();
                },
                segments: [
                  for (final type in RepaymentType.values)
                    AppSegment(
                      key: Key('mortgageFormRepayment-${type.wireValue}'),
                      value: type,
                      label: repaymentTypeLabel(l10n, type),
                    ),
                ],
              ),
            ),
            rowGap,
            _pair(
              LabeledField(
                label: l10n.mortgageFormPrincipal,
                child: MoneyField(
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
              LabeledField(
                label: l10n.mortgageFormRate,
                errorText: _rateError,
                child: TextFormField(
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
            ),
            rowGap,
            _pair(
              LabeledField(
                label: l10n.mortgageFormTerm,
                child: TextFormField(
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
              LabeledField(
                label: l10n.mortgageFormFirstPayment,
                child: DateField(
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
            ),
            rowGap,
            _pair(
              LabeledField(
                label: l10n.mortgageFormInsurance,
                child: MoneyField(
                  key: const Key('mortgageFormInsurance'),
                  controller: _insuranceController,
                  currency: currency,
                  validator: (value) => _optionalMoney(value ?? '') == null
                      ? l10n.mortgageFormAmountOptionalInvalid
                      : null,
                ),
              ),
              LabeledField(
                label: l10n.mortgageFormFees,
                errorText: _feesError,
                child: MoneyField(
                  key: const Key('mortgageFormFees'),
                  controller: _feesController,
                  currency: currency,
                  validator: (value) => _optionalMoney(value ?? '') == null
                      ? l10n.mortgageFormAmountOptionalInvalid
                      : null,
                ),
              ),
            ),
            if (properties.isNotEmpty || _propertyId != null) ...[
              rowGap,
              LabeledField(
                label: l10n.mortgageFormProperty,
                errorText: _propertyError,
                child: AppSelect<String?>(
                  key: const Key('mortgageFormProperty'),
                  value: _propertyId,
                  onChanged: (value) => setState(() => _propertyId = value),
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
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _InstalmentPlate(
              interestOnly: _repayment == RepaymentType.interestOnly,
              preview: preview,
            ),
          ],
        ),
      ),
    );
  }
}

/// The read-only « Mensualité calculée » plate — dashed, on the field tone, with
/// the lock glyph — following the fields live.
class _InstalmentPlate extends StatelessWidget {
  const _InstalmentPlate({required this.interestOnly, required this.preview});

  final bool interestOnly;
  final AsyncValue<ComputedInstalment>? preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    final Widget content;
    if (interestOnly) {
      content = Text(
        l10n.mortgageFormPlateInterestOnly,
        key: const Key('mortgageFormPlateInterestOnly'),
        style: secondary,
      );
    } else {
      content = switch (preview) {
        AsyncData(:final value) => Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.mortgageFormPlateLabel, style: secondary),
            AmountText(
              key: const Key('mortgageFormPlateAmount'),
              amountMinor: value.monthlyPaymentMinor,
              currency: value.currency,
              colorize: false,
              style: textTheme.titleSmall,
            ),
            Text(
              '· ${l10n.mortgageFormPlateDetail(formatAmount(amountMinor: value.totalInstalmentMinor, currency: value.currency, locale: locale), formatAmount(amountMinor: value.totalInterestMinor, currency: value.currency, locale: locale))}',
              key: const Key('mortgageFormPlateDetail'),
              style: tabularNumberStyle(secondary!),
            ),
          ],
        ),
        AsyncError(:final error) => Text(
          localizeMortgageError(l10n, error),
          key: const Key('mortgageFormPlateError'),
          style: textTheme.bodySmall?.copyWith(color: AppColors.negative),
        ),
        _ => Text(
          l10n.mortgageFormPlatePending,
          key: const Key('mortgageFormPlatePending'),
          style: secondary,
        ),
      };
    }

    return DashedBorder(
      child: Container(
        key: const Key('mortgageFormPlate'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceField,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: AppColors.textDisabled,
            ),
            const SizedBox(width: 10),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
