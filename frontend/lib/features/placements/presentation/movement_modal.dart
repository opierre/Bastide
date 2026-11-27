import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';
import 'placement_form_modal.dart';
import 'placement_labels.dart';

/// Opens « Versement ou retrait », or its edit form with [initial].
Future<void> showMovementModal(
  BuildContext context, {
  required Investment investment,
  InvestmentMovement? initial,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => MovementModal(investment: investment, initial: initial),
  );
}

/// The 440 px movement modal (`17-placements.md` §Modals): Montant (a
/// negative amount is a withdrawal) · Date · Note · Transaction liée, a
/// select of the imported transfers of the opposite amount near that date.
/// The link is for the user's reference and changes no total.
class MovementModal extends ConsumerStatefulWidget {
  const MovementModal({super.key, required this.investment, this.initial});

  final Investment investment;
  final InvestmentMovement? initial;

  @override
  ConsumerState<MovementModal> createState() => _MovementModalState();
}

class _MovementModalState extends ConsumerState<MovementModal> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _date = TextEditingController();
  late final _note = TextEditingController(text: widget.initial?.note);
  late String? _transactionId = widget.initial?.transactionId;
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
    ).format(initial?.occurredOn ?? DateTime.now());
    if (initial != null) {
      _amount.text = formatMoneyInput(initial.amountMinor, locale);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _parseAmount(String text, String locale) {
    final minor = parseMoneyMinor(text, locale, allowNegative: true);
    return (minor == null || minor == 0) ? null : minor;
  }

  /// The lookup the « Transaction liée » select lists, once the amount and
  /// the date both read.
  LinkQuery? _query(String locale) {
    final amount = _parseAmount(_amount.text, locale);
    final date = parsePastDate(_date.text, locale);
    if (amount == null || date == null) return null;
    return (
      investmentId: widget.investment.id,
      amountMinor: amount,
      on: date,
      movementId: widget.initial?.id,
    );
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

  Future<void> _submit(List<LinkCandidate>? candidates) async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).toString();
    final amount = _parseAmount(_amount.text, locale);
    final date = parsePastDate(_date.text, locale);
    if (amount == null || date == null) return;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    // A link the new amount or date no longer offers is dropped.
    final link =
        candidates == null ||
            candidates.any((c) => c.transactionId == _transactionId)
        ? _transactionId
        : null;
    final id = widget.investment.id;
    final initial = widget.initial;
    await _run(
      (controller) => initial == null
          ? controller.addMovement(
              id,
              occurredOn: date,
              amountMinor: amount,
              note: note,
              transactionId: link,
            )
          : controller.updateMovement(
              id,
              initial.id,
              occurredOn: date,
              amountMinor: amount,
              note: note,
              transactionId: link,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final initial = widget.initial;
    final query = _query(locale);
    final candidates = query == null
        ? null
        : ref.watch(linkCandidatesProvider(query)).value;
    const gap = SizedBox(height: AppSpacing.fieldGap);
    void changed(String _) => setState(() {});

    return AppModal(
      key: const Key('movementModal'),
      title: initial == null
          ? l10n.placementAddMovement
          : l10n.placementMovementEditTitle,
      subtitle: Text(widget.investment.name),
      width: AppSizes.inspector,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: () => _submit(candidates),
      leadingAction: initial == null
          ? null
          : AppButton(
              key: const Key('movementDelete'),
              label: l10n.placementFormDelete,
              variant: AppButtonVariant.ghost,
              onPressed: _isSubmitting
                  ? null
                  : () => _run(
                      (controller) => controller.deleteMovement(
                        widget.investment.id,
                        initial.id,
                      ),
                    ),
            ),
      actions: [
        const AppModalCancel(key: Key('movementCancel')),
        PrimaryButton(
          key: const Key('movementSubmit'),
          label: l10n.placementFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : () => _submit(candidates),
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
              label: l10n.placementMovementAmount,
              helper: l10n.placementMovementAmountHelp,
              child: MoneyField(
                key: const Key('movementAmount'),
                controller: _amount,
                currency: widget.investment.currency,
                allowNegative: true,
                autofocus: true,
                onChanged: changed,
                validator: (value) => _parseAmount(value ?? '', locale) == null
                    ? l10n.placementMovementAmountInvalid
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementFieldDate,
              child: DateField(
                key: const Key('movementDate'),
                controller: _date,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                calendarTooltip: l10n.placementFormDatePick,
                onChanged: (_) => setState(() {}),
                validator: (value) => parsePastDate(value ?? '', locale) == null
                    ? l10n.placementFormDateInvalid
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementFieldNote,
              child: TextFormField(
                key: const Key('movementNote'),
                controller: _note,
                decoration: InputDecoration(
                  hintText: l10n.placementMovementNoteHint,
                ),
              ),
            ),
            gap,
            LabeledField(
              label: l10n.placementMovementLink,
              helper: l10n.placementMovementLinkHelp,
              child: AppSelect<String?>(
                key: const Key('movementLink'),
                value:
                    candidates == null ||
                        candidates.any((c) => c.transactionId == _transactionId)
                    ? _transactionId
                    : null,
                items: [
                  AppSelectItem(
                    value: null,
                    label: l10n.placementMovementLinkNone,
                  ),
                  for (final candidate in candidates ?? const <LinkCandidate>[])
                    // The bank label in Geist Mono, then its date and amount.
                    AppSelectItem(
                      value: candidate.transactionId,
                      label: candidate.description,
                      mono: true,
                      detail: l10n.placementMovementLinkDetail(
                        placementDateLabel(locale, candidate.bookedDate),
                        placementMoney(
                          candidate.amountMinor,
                          candidate.currency,
                          locale,
                        ),
                      ),
                      subtitle: candidate.accountName,
                    ),
                ],
                onChanged: _isSubmitting || candidates == null
                    ? null
                    : (id) => setState(() {
                        _transactionId = id;
                        _dirty = true;
                      }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
