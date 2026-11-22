import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';
import 'placement_form_modal.dart';
import 'placement_labels.dart';

/// Opens « Saisir la valeur », or its edit form with [initial].
Future<void> showValuationModal(
  BuildContext context, {
  required Investment investment,
  InvestmentValuation? initial,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => ValuationModal(investment: investment, initial: initial),
  );
}

/// The 440 px value modal (`17-placements.md` §Modals): the placement's
/// name as lead; Valeur · Date (today by default, never ahead) · Note.
/// Editing adds a ghost « Supprimer » on the footer's left.
class ValuationModal extends ConsumerStatefulWidget {
  const ValuationModal({super.key, required this.investment, this.initial});

  final Investment investment;
  final InvestmentValuation? initial;

  @override
  ConsumerState<ValuationModal> createState() => _ValuationModalState();
}

class _ValuationModalState extends ConsumerState<ValuationModal> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _date = TextEditingController();
  late final _note = TextEditingController(text: widget.initial?.note);
  bool _filled = false;
  bool _dirty = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final locale = Localizations.localeOf(context).toString();
    final initial = widget.initial;
    _date.text = appDateFormat(
      locale,
    ).format(initial?.valuedOn ?? DateTime.now());
    if (initial != null) {
      _value.text = formatMoneyInput(initial.valueMinor, locale);
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _date.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(PlacementsController) write) async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await write(ref.read(placementsControllerProvider.notifier));
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).toString();
    final value = parseMoneyMinor(_value.text, locale);
    final date = parsePastDate(_date.text, locale);
    if (value == null || date == null) return;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final id = widget.investment.id;
    final initial = widget.initial;
    await _run(
      (controller) => initial == null
          ? controller.addValuation(
              id,
              valuedOn: date,
              valueMinor: value,
              note: note,
            )
          : controller.updateValuation(
              id,
              initial.id,
              valuedOn: date,
              valueMinor: value,
              note: note,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final initial = widget.initial;
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('valuationModal'),
      title: initial == null
          ? l10n.placementEnterValue
          : l10n.placementValuationEditTitle,
      subtitle: Text(widget.investment.name),
      width: AppSizes.inspector,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: _submit,
      leadingAction: initial == null
          ? null
          : AppButton(
              key: const Key('valuationDelete'),
              label: l10n.placementFormDelete,
              variant: AppButtonVariant.ghost,
              onPressed: _isSubmitting
                  ? null
                  : () => _run(
                      (controller) => controller.deleteValuation(
                        widget.investment.id,
                        initial.id,
                      ),
                    ),
            ),
      actions: [
        const AppModalCancel(key: Key('valuationCancel')),
        PrimaryButton(
          key: const Key('valuationSubmit'),
          label: l10n.placementFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: l10n.placementValuationValue,
              helper: l10n.placementValuationHelp,
              child: MoneyField(
                key: const Key('valuationValue'),
                controller: _value,
                currency: widget.investment.currency,
                autofocus: true,
                textAlign: TextAlign.end,
                validator: (value) =>
                    parseMoneyMinor(value ?? '', locale) == null
                    ? l10n.placementValuationValueInvalid
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementFieldDate,
              child: DateField(
                key: const Key('valuationDate'),
                controller: _date,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                calendarTooltip: l10n.placementFormDatePick,
                validator: (value) => parsePastDate(value ?? '', locale) == null
                    ? l10n.placementFormDateInvalid
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementFieldNote,
              child: TextFormField(
                key: const Key('valuationNote'),
                controller: _note,
                decoration: InputDecoration(
                  hintText: l10n.placementValuationNoteHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
