import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';
import 'delete_placement_modal.dart';
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

/// The 440 px placement modal (`17-placements.md` §Modals, proposal v6
/// `m-investments`): Nom · Enveloppe, then Établissement and Date
/// d’ouverture side by side, and on creation the optional Valeur actuelle
/// and Versements déjà effectués side by side. Editing puts a ghost
/// « Supprimer » on the footer's left.
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
  bool _dirty = false;
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

  /// The destructive confirmation, over the form; the form closes once the
  /// placement is gone.
  Future<void> _delete() async {
    final deleted = await showDeletePlacementModal(
      context,
      investment: widget.initial!,
    );
    if (deleted == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
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
    // The placeholder of an optional amount: « 0,00 ».
    final zero = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    ).format(0);
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('placementFormModal'),
      title: _isEditing
          ? l10n.placementFormEditTitle
          : l10n.placementFormCreateTitle,
      width: AppSizes.inspector,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: _submit,
      leadingAction: _isEditing
          ? AppButton(
              key: const Key('placementFormDelete'),
              label: l10n.placementFormDelete,
              variant: AppButtonVariant.ghost,
              onPressed: _isSubmitting ? null : _delete,
            )
          : null,
      actions: [
        const AppModalCancel(key: Key('placementFormCancel')),
        PrimaryButton(
          key: const Key('placementFormSubmit'),
          label: l10n.placementFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        // Typed input makes the form dirty: the scrim no longer closes it.
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    : (envelope) => setState(() {
                        _envelope = envelope;
                        _dirty = true;
                      }),
              ),
            ),
            gap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.placementFormInstitution,
                input: TextFormField(
                  key: const Key('placementFormInstitution'),
                  controller: _institution,
                  // The monogram the placement will carry, live as it is
                  // typed, inside the field as in the accounts form.
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.xsPlus,
                        end: AppSpacing.sm,
                      ),
                      child: MonogramAvatar(
                        key: const Key('placementFormMonogram'),
                        name: _institution.text,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                  ),
                  validator: (value) =>
                      required(value, l10n.placementFormInstitutionRequired),
                ),
              ),
              end: ModalFieldCell(
                label: l10n.placementFormOpenedOn,
                input: DateField(
                  key: const Key('placementFormOpenedOn'),
                  controller: _openedOn,
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                  calendarTooltip: l10n.placementFormDatePick,
                  validator: (value) =>
                      parsePastDate(value ?? '', locale) == null
                      ? l10n.placementFormDateInvalid
                      : null,
                ),
              ),
            ),
            if (!_isEditing) ...[
              gap,
              // « Versements déjà effectués (facultatif) » wraps onto two
              // lines in French: both inputs move down together (`00` §7).
              ModalFieldRow(
                key: const Key('placementFormOptionalRow'),
                start: ModalFieldCell(
                  label: l10n.placementFormCurrentValue,
                  input: MoneyField(
                    key: const Key('placementFormValue'),
                    controller: _value,
                    currency: currency,
                    hintText: zero,
                    validator: amount,
                  ),
                ),
                end: ModalFieldCell(
                  label: l10n.placementFormInitialPayments,
                  helper: l10n.placementFormInitialPaymentsHelp,
                  input: MoneyField(
                    key: const Key('placementFormPayments'),
                    controller: _payments,
                    currency: currency,
                    hintText: zero,
                    validator: (value) => amount(value, allowZero: false),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
