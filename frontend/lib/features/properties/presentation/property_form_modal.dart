import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
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
import '../application/properties_controller.dart';
import '../domain/property.dart';

/// Opens the create/edit property modal. [currency] is the user's, for the
/// amount fields' unit. Resolves to the saved property, or `null` on cancel.
Future<Property?> showPropertyForm(
  BuildContext context, {
  required String currency,
  Property? initial,
}) {
  return showAppModal<Property>(
    context: context,
    builder: (_) => PropertyFormModal(currency: currency, initial: initial),
  );
}

/// Opens the « Nouvelle estimation » modal for [property].
Future<Property?> showRevalueForm(BuildContext context, Property property) {
  return showAppModal<Property>(
    context: context,
    builder: (_) => PropertyRevalueModal(property: property),
  );
}

/// Reads a typed ownership percent as basis points — « 50 » → 5000,
/// « 33,33 » → 3333.
///
/// The one place ownership changes unit (shares are bps).
/// Done on the digits rather than through a double, so 33,33 can never come
/// out as 3332. Accepts a comma or a point, at most two decimals, and only a
/// share the API accepts: above 0 and at most 100 %.
int? parseOwnershipBps(String raw) {
  final match = RegExp(r'^\s*(\d{1,3})(?:[.,](\d{0,2}))?\s*$').firstMatch(raw);
  if (match == null) return null;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final bps = int.parse(match.group(1)!) * 100 + int.parse(fraction);
  return bps < 1 || bps > fullOwnershipBps ? null : bps;
}

/// The inverse, for prefilling the field in the locale's own spelling —
/// « 50 », « 33,33 ».
String formatOwnershipInput(int bps, String locale) {
  final whole = '${bps ~/ 100}';
  if (bps % 100 == 0) return whole;
  final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  return '$whole$separator${(bps % 100).toString().padLeft(2, '0')}';
}

/// An ownership share printed as the locale's percent — « 50 % », « 33,33 % ».
String formatOwnershipShare(int bps, String locale) {
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 2;
  return format.format(bps / fullOwnershipBps);
}

/// The ARB label of a property's nature — the backend stores the machine value.
String propertyKindLabel(AppLocalizations l10n, PropertyKind kind) =>
    switch (kind) {
      PropertyKind.primaryResidence => l10n.propertyKindPrimaryResidence,
      PropertyKind.rental => l10n.propertyKindRental,
      PropertyKind.secondary => l10n.propertyKindSecondary,
      PropertyKind.other => l10n.propertyKindOther,
    };

/// Whether a refused write belongs under the valuation date — the one field
/// the server refuses on its own (a date in the future).
bool isValuationDateError(Object? error) =>
    error is ApiFailure && error.code == 'PROPERTY_VALUATION_IN_FUTURE';

/// Maps the properties feature's stable error `code`s (see
/// `backend/app/features/properties/service.py`) to a localized message.
String localizePropertyError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'PROPERTY_VALUATION_IN_FUTURE':
        return l10n.propertyErrorValuationInFuture;
      case 'PROPERTY_NOT_FOUND':
        return l10n.propertyErrorNotFound;
      case 'VALIDATION_ERROR':
        return l10n.propertyErrorValidation;
    }
  }
  return l10n.propertyErrorGeneric;
}

/// The 620 px « Nouveau bien » modal (`15-synthese.md` §Modals), reused
/// prefilled for « Modifier le bien ». Two columns, fields 14 px apart, the
/// address full width.
class PropertyFormModal extends ConsumerStatefulWidget {
  const PropertyFormModal({super.key, required this.currency, this.initial});

  final String currency;
  final Property? initial;

  @override
  ConsumerState<PropertyFormModal> createState() => _PropertyFormModalState();
}

class _PropertyFormModalState extends ConsumerState<PropertyFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(
    text: widget.initial?.label,
  );
  late final _addressController = TextEditingController(
    text: widget.initial?.address,
  );
  final _valueController = TextEditingController();
  final _valuedOnController = TextEditingController();
  final _ownershipController = TextEditingController();
  final _priceController = TextEditingController();
  final _acquiredOnController = TextEditingController();

  late PropertyKind _kind =
      widget.initial?.kind ?? PropertyKind.primaryResidence;

  /// Guards the one-time locale-aware fill, which needs the active locale and
  /// so cannot run in `initState`.
  bool _filled = false;
  bool _isSubmitting = false;
  String? _valuedOnError;
  String? _bannerError;

  bool get _isEditing => widget.initial != null;

  String get _locale => Localizations.localeOf(context).toString();

  /// Every text input, for the listeners and for [_dirty].
  List<TextEditingController> get _inputs => [
    _labelController,
    _addressController,
    _valueController,
    _valuedOnController,
    _ownershipController,
    _priceController,
    _acquiredOnController,
  ];

  /// What the form held once filled: input differing from it is unsaved.
  List<String> _pristine = const [];

  bool get _dirty =>
      _kind != (widget.initial?.kind ?? PropertyKind.primaryResidence) ||
      [
        for (final c in _inputs) c.text,
      ].indexed.any((entry) => entry.$2 != _pristine[entry.$1]);

  @override
  void initState() {
    super.initState();
    // The live « part : … » label and the unsaved-input state follow every
    // input.
    for (final controller in _inputs) {
      controller.addListener(_onInputChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    _fill();
    _pristine = [for (final c in _inputs) c.text];
  }

  void _fill() {
    final initial = widget.initial;
    final locale = _locale;
    if (initial == null) {
      _ownershipController.text = formatOwnershipInput(
        fullOwnershipBps,
        locale,
      );
      return;
    }
    _valueController.text = formatMoneyInput(initial.marketValueMinor, locale);
    _valuedOnController.text = appDateFormat(locale).format(initial.valuedOn);
    _ownershipController.text = formatOwnershipInput(
      initial.ownershipBps,
      locale,
    );
    if (initial.acquisitionPriceMinor case final price?) {
      _priceController.text = formatMoneyInput(price, locale);
    }
    if (initial.acquiredOn case final acquiredOn?) {
      _acquiredOnController.text = appDateFormat(locale).format(acquiredOn);
    }
  }

  @override
  void dispose() {
    for (final controller in _inputs) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  /// The held share of the value being typed, or `null` while either input
  /// doesn't read as one.
  int? get _liveShareMinor {
    final value = parseMoneyMinor(_valueController.text, _locale);
    final ownership = parseOwnershipBps(_ownershipController.text);
    if (value == null || value <= 0 || ownership == null) return null;
    return previewHeldShareMinor(value, ownership);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale;
    final priceText = _priceController.text.trim();
    final acquiredText = _acquiredOnController.text.trim();
    final addressText = _addressController.text.trim();
    final draft = PropertyDraft(
      label: _labelController.text.trim(),
      address: addressText.isEmpty ? null : addressText,
      kind: _kind,
      marketValueMinor: parseMoneyMinor(_valueController.text, locale)!,
      valuedOn: parseDateInput(_valuedOnController.text, locale)!,
      ownershipBps: parseOwnershipBps(_ownershipController.text)!,
      acquisitionPriceMinor: priceText.isEmpty
          ? null
          : parseMoneyMinor(priceText, locale),
      acquiredOn: acquiredText.isEmpty
          ? null
          : parseDateInput(acquiredText, locale),
    );

    setState(() {
      _isSubmitting = true;
      _valuedOnError = _bannerError = null;
    });

    final controller = ref.read(propertiesControllerProvider.notifier);
    try {
      final saved = _isEditing
          ? await controller.updateProperty(widget.initial!.id, draft)
          : await controller.create(draft);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      final message = localizePropertyError(l10n, error);
      setState(() {
        _isSubmitting = false;
        if (isValuationDateError(error)) {
          _valuedOnError = message;
        } else {
          _bannerError = message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale;
    final liveShare = _liveShareMinor;
    const rowGap = SizedBox(height: AppSpacing.fieldGap);

    String? optionalDate(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return null;
      return parseDateInput(text, locale) == null
          ? l10n.propertyFormDateInvalid
          : null;
    }

    return AppModal(
      title: _isEditing
          ? l10n.propertyFormEditTitle
          : l10n.propertyFormCreateTitle,
      width: AppModalSizes.w620,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _bannerError,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(),
        PrimaryButton(
          key: const Key('propertyFormSubmit'),
          label: l10n.propertyFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      // Libellé and Adresse full width, then three pairs, so the grid leaves
      // no empty cell (mockup `#panel=m-networth`).
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: l10n.propertyFormLabel,
              child: TextFormField(
                key: const Key('propertyFormLabel'),
                controller: _labelController,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.propertyFormLabelRequired
                    : null,
              ),
            ),
            rowGap,
            // An address runs longer than any other field, and it is what
            // tells two similar biens apart.
            LabeledField(
              label: l10n.propertyFormAddress,
              child: TextFormField(
                key: const Key('propertyFormAddress'),
                controller: _addressController,
                keyboardType: TextInputType.streetAddress,
                inputFormatters: [
                  // The API's limit (`ADDRESS_MAX_LENGTH`), so nothing typed
                  // can be refused on save.
                  LengthLimitingTextInputFormatter(propertyAddressMaxLength),
                ],
              ),
            ),
            rowGap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.propertyFormKind,
                input: AppSelect<PropertyKind>(
                  key: const Key('propertyFormKind'),
                  value: _kind,
                  onChanged: (value) => setState(() => _kind = value),
                  items: [
                    for (final kind in PropertyKind.values)
                      AppSelectItem(
                        value: kind,
                        label: propertyKindLabel(l10n, kind),
                      ),
                  ],
                ),
              ),
              end: ModalFieldCell(
                label: l10n.propertyFormOwnership,
                // The label carries the held share live, so the user sees
                // what enters the synthèse before saving (`15` §Modals). A
                // reading, not an action: `textTertiary`, never the accent.
                trailing: liveShare == null
                    ? null
                    : Text(
                        l10n.propertyFormOwnershipShare(
                          formatAmount(
                            amountMinor: liveShare,
                            currency: widget.currency,
                            locale: locale,
                          ),
                        ),
                        key: const Key('propertyFormOwnershipShare'),
                        style: tabularNumberStyle(
                          Theme.of(context).textTheme.bodySmall!,
                        ).copyWith(color: context.colors.textTertiary),
                      ),
                input: TextFormField(
                  key: const Key('propertyFormOwnership'),
                  controller: _ownershipController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textAlign: TextAlign.right,
                  style: tabularNumberStyle(
                    Theme.of(context).textTheme.bodyLarge!,
                  ),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: fieldSuffixStyle(context),
                  ),
                  validator: (value) => parseOwnershipBps(value ?? '') == null
                      ? l10n.propertyFormOwnershipInvalid
                      : null,
                ),
              ),
            ),
            rowGap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.propertyFormValue,
                input: MoneyField(
                  key: const Key('propertyFormValue'),
                  controller: _valueController,
                  currency: widget.currency,
                  validator: (value) {
                    final amount = parseMoneyMinor(value ?? '', locale);
                    return amount == null || amount <= 0
                        ? l10n.propertyFormAmountInvalid
                        : null;
                  },
                ),
              ),
              end: ModalFieldCell(
                label: l10n.propertyFormValuedOn,
                errorText: _valuedOnError,
                input: DateField(
                  key: const Key('propertyFormValuedOn'),
                  controller: _valuedOnController,
                  firstDate: DateTime(1900),
                  // A valuation is a fact already given, never a forecast.
                  lastDate: DateTime.now(),
                  calendarTooltip: l10n.propertyFormCalendar,
                  validator: (value) =>
                      parseDateInput(value ?? '', locale) == null
                      ? l10n.propertyFormDateInvalid
                      : null,
                ),
              ),
            ),
            rowGap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.propertyFormAcquisitionPrice,
                input: MoneyField(
                  key: const Key('propertyFormAcquisitionPrice'),
                  controller: _priceController,
                  currency: widget.currency,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    return parseMoneyMinor(text, locale) == null
                        ? l10n.propertyFormAmountOptionalInvalid
                        : null;
                  },
                ),
              ),
              end: ModalFieldCell(
                label: l10n.propertyFormAcquiredOn,
                input: DateField(
                  key: const Key('propertyFormAcquiredOn'),
                  controller: _acquiredOnController,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  calendarTooltip: l10n.propertyFormCalendar,
                  validator: optionalDate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// « Nouvelle estimation »: a new declared value with the date it was given.
///
/// The API keeps one declared value per property, so this replaces the
/// previous one. The 420 px modal of `15-synthese.md` §Modals.
class PropertyRevalueModal extends ConsumerStatefulWidget {
  const PropertyRevalueModal({super.key, required this.property});

  final Property property;

  @override
  ConsumerState<PropertyRevalueModal> createState() =>
      _PropertyRevalueModalState();
}

class _PropertyRevalueModalState extends ConsumerState<PropertyRevalueModal> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _valuedOnController = TextEditingController();
  bool _isSubmitting = false;
  String? _valuedOnError;
  String? _bannerError;

  String get _locale => Localizations.localeOf(context).toString();

  /// Both inputs open empty: anything typed is unsaved.
  bool get _dirty =>
      _valueController.text.isNotEmpty || _valuedOnController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _valueController.addListener(_onInputChanged);
    _valuedOnController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _valueController.dispose();
    _valuedOnController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale;
    setState(() {
      _isSubmitting = true;
      _valuedOnError = _bannerError = null;
    });
    try {
      final saved = await ref
          .read(propertiesControllerProvider.notifier)
          .revalue(
            widget.property.id,
            marketValueMinor: parseMoneyMinor(_valueController.text, locale)!,
            valuedOn: parseDateInput(_valuedOnController.text, locale)!,
          );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      final message = localizePropertyError(l10n, error);
      setState(() {
        _isSubmitting = false;
        if (isValuationDateError(error)) {
          _valuedOnError = message;
        } else {
          _bannerError = message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale;
    final property = widget.property;

    return AppModal(
      title: l10n.propertyRevalueTitle,
      // « Studio : 145 000,00 € estimés le 15 mars 2026. » The date is
      // written out, as in running text (mockup `#panel=m-networth`).
      subtitle: Text(
        l10n.propertyRevalueSubtitle(
          property.label,
          formatAmount(
            amountMinor: property.marketValueMinor,
            currency: property.currency,
            locale: locale,
          ),
          DateFormat.yMMMMd(locale).format(property.valuedOn),
        ),
        key: const Key('propertyRevalueSubtitle'),
      ),
      width: AppModalSizes.w420,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _bannerError,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(),
        PrimaryButton(
          key: const Key('propertyRevalueSubmit'),
          label: l10n.propertyFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: ModalFieldRow(
          start: ModalFieldCell(
            label: l10n.propertyFormValue,
            input: MoneyField(
              key: const Key('propertyRevalueValue'),
              controller: _valueController,
              currency: property.currency,
              validator: (value) {
                final amount = parseMoneyMinor(value ?? '', locale);
                return amount == null || amount <= 0
                    ? l10n.propertyFormAmountInvalid
                    : null;
              },
            ),
          ),
          end: ModalFieldCell(
            label: l10n.propertyFormValuedOn,
            errorText: _valuedOnError,
            input: DateField(
              key: const Key('propertyRevalueValuedOn'),
              controller: _valuedOnController,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              calendarTooltip: l10n.propertyFormCalendar,
              validator: (value) => parseDateInput(value ?? '', locale) == null
                  ? l10n.propertyFormDateInvalid
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
