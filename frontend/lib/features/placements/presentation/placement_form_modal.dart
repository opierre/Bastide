import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';
import 'placement_labels.dart';

/// Opens the « Nouveau placement » modal, or « Modifier » with [initial].
Future<void> showPlacementForm(BuildContext context, {Investment? initial}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => PlacementFormModal(initial: initial),
  );
}

/// A date the user typed, or `null` when it is unreadable or in the future:
/// every date of this panel is something that already happened.
DateTime? parsePastDate(String text, String locale) {
  final date = parseDateInput(text, locale);
  if (date == null) return null;
  final now = DateTime.now();
  return date.isAfter(DateTime(now.year, now.month, now.day)) ? null : date;
}

/// The 440 px placement modal (`17-placements.md` §Modals): Nom ·
/// Enveloppe · Établissement · Date d’ouverture, and on creation the
/// optional Valeur actuelle and Versements déjà effectués.
class PlacementFormModal extends ConsumerStatefulWidget {
  const PlacementFormModal({super.key, this.initial});

  final Investment? initial;

  @override
  ConsumerState<PlacementFormModal> createState() => _PlacementFormModalState();
}

class _PlacementFormModalState extends ConsumerState<PlacementFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _institution = TextEditingController(
    text: widget.initial?.institution,
  );
  final _openedOn = TextEditingController();
  final _value = TextEditingController();
  final _payments = TextEditingController();
  late Envelope _envelope = widget.initial?.envelope ?? Envelope.pea;
  bool _filled = false;
  bool _isSubmitting = false;
  String? _errorText;

  bool get _isEditing => widget.initial != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final locale = Localizations.localeOf(context).toString();
    _openedOn.text = appDateFormat(
      locale,
    ).format(widget.initial?.openedOn ?? DateTime.now());
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _openedOn.dispose();
    _value.dispose();
    _payments.dispose();
    super.dispose();
  }

  /// An optional amount: `null` when empty, `-1` when unreadable.
  int? _optionalAmount(String text, String locale, {bool allowZero = true}) {
    if (text.trim().isEmpty) return null;
    final minor = parseMoneyMinor(text, locale);
    if (minor == null || minor < 0 || (!allowZero && minor == 0)) return -1;
    return minor;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).toString();
    final openedOn = parsePastDate(_openedOn.text, locale);
    if (openedOn == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final controller = ref.read(placementsControllerProvider.notifier);
    try {
      if (_isEditing) {
        await controller.updatePlacement(
          widget.initial!.id,
          name: _name.text.trim(),
          institution: _institution.text.trim(),
          envelope: _envelope,
          openedOn: openedOn,
        );
      } else {
        await controller.create(
          name: _name.text.trim(),
          institution: _institution.text.trim(),
          envelope: _envelope,
          openedOn: openedOn,
          initialValueMinor: _optionalAmount(_value.text, locale),
          initialPaymentsMinor: _optionalAmount(
            _payments.text,
            locale,
            allowZero: false,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizePlacementError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final currency =
        widget.initial?.currency ??
        ref.watch(currentUserProvider)?.currency ??
        '';
    String? required(String? value, String message) =>
        (value == null || value.trim().isEmpty) ? message : null;
    String? amount(String? value, {bool allowZero = true}) =>
        _optionalAmount(value ?? '', locale, allowZero: allowZero) == -1
        ? l10n.placementFormAmountInvalid
        : null;
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('placementFormModal'),
      title: _isEditing
          ? l10n.placementFormEditTitle
          : l10n.placementFormCreateTitle,
      width: AppSizes.inspector,
      actions: [
        OutlinedButton(
          key: const Key('placementFormCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.placementFormCancel),
        ),
        PrimaryButton(
          key: const Key('placementFormSubmit'),
          label: l10n.placementFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null) ...[
              InlineBanner(
                key: const Key('placementFormError'),
                message: _errorText!,
              ),
              gap,
            ],
            LabeledField(
              label: l10n.placementFormName,
              child: TextFormField(
                key: const Key('placementFormName'),
                controller: _name,
                autofocus: true,
                validator: (value) =>
                    required(value, l10n.placementFormNameRequired),
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementFormEnvelope,
              child: AppSelect<Envelope>(
                key: const Key('placementFormEnvelope'),
                value: _envelope,
                items: [
                  for (final envelope in Envelope.values)
                    AppSelectItem(
                      value: envelope,
                      label: envelopeLabel(l10n, envelope),
                    ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (envelope) => setState(() => _envelope = envelope),
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementFormInstitution,
              child: TextFormField(
                key: const Key('placementFormInstitution'),
                controller: _institution,
                validator: (value) =>
                    required(value, l10n.placementFormInstitutionRequired),
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementFormOpenedOn,
              child: DateField(
                key: const Key('placementFormOpenedOn'),
                controller: _openedOn,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                calendarTooltip: l10n.placementFormDatePick,
                validator: (value) => parsePastDate(value ?? '', locale) == null
                    ? l10n.placementFormDateInvalid
                    : null,
              ),
            ),
            if (!_isEditing) ...[
              gap,
              LabeledField(
                label: l10n.placementFormCurrentValue,
                helper: l10n.placementFormCurrentValueHelp,
                child: MoneyField(
                  key: const Key('placementFormValue'),
                  controller: _value,
                  currency: currency,
                  textAlign: TextAlign.end,
                  validator: amount,
                ),
              ),
              gap,
              LabeledField(
                label: l10n.placementFormInitialPayments,
                helper: l10n.placementFormInitialPaymentsHelp,
                child: MoneyField(
                  key: const Key('placementFormPayments'),
                  controller: _payments,
                  currency: currency,
                  textAlign: TextAlign.end,
                  validator: (value) => amount(value, allowZero: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
