import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';
import 'goal_labels.dart';

/// Opens the 440 px « Nouvelle allocation » modal over the goal detail. Resolves
/// to the appended line, or `null` when the user cancelled.
Future<GoalAllocation?> showAllocationModal(
  BuildContext context, {
  required Goal goal,
}) {
  return showAppModal<GoalAllocation>(
    context: context,
    builder: (_) => AllocationModal(goal: goal),
  );
}

/// One signed amount, a date, and an optional note, one under the other, with
/// the goal's name as lead (`docs/design/11-goals.md` §Modals, proposal v6
/// `m-goals`).
///
/// **One field, no deposit/withdraw modes.** Taking money back out of an
/// envelope is the same act as putting it in, with the other sign; two verbs
/// over one mechanism would invite the user to expect two histories, when the
/// ledger is deliberately a single signed list. The goal's name is the only
/// context on the modal — no account, because there isn't one.
class AllocationModal extends ConsumerStatefulWidget {
  const AllocationModal({super.key, required this.goal});

  final Goal goal;

  @override
  ConsumerState<AllocationModal> createState() => _AllocationModalState();
}

class _AllocationModalState extends ConsumerState<AllocationModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _noteController = TextEditingController();

  /// Guards the one-time locale-aware fill of the date field. Done in
  /// [didChangeDependencies] because the value must round-trip through the same
  /// formatter that re-parses it on submit, and that needs the active locale —
  /// unavailable before the widget is mounted.
  bool _filled = false;

  bool _dirty = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    // Today, because that is when nearly every allocation is entered — and a
    // pre-filled date the user can overwrite beats an empty field they must
    // fill to move on.
    final locale = Localizations.localeOf(context).toString();
    _dateController.text = appDateFormat(locale).format(DateTime.now());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The signed amount in minor units, or `null` when the field doesn't hold a
  /// usable one. Zero is refused: an allocation of nothing is a line that says
  /// nothing, and the ledger is read as a record of decisions.
  int? _parseAmount(String text, String locale) {
    final minor = parseMoneyMinor(text, locale, allowNegative: true);
    return (minor == null || minor == 0) ? null : minor;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final locale = Localizations.localeOf(context).toString();
    final amount = _parseAmount(_amountController.text, locale);
    final date = parseDateInput(_dateController.text, locale);
    if (amount == null || date == null) return;

    final note = _noteController.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final allocation = await ref
          .read(goalsControllerProvider.notifier)
          .allocate(
            widget.goal.id,
            amountMinor: amount,
            allocatedOn: date,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      Navigator.of(context).pop(allocation);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeGoalError(AppLocalizations.of(context)!, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final currency = widget.goal.currency;

    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('allocationModal'),
      title: l10n.allocationModalTitle,
      subtitle: Text(widget.goal.name, key: const Key('allocationGoalName')),
      width: AppModalSizes.w440,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('allocationCancel')),
        PrimaryButton(
          key: const Key('allocationSubmit'),
          label: l10n.allocationSubmit,
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
              label: l10n.allocationAmountLabel,
              helper: l10n.allocationAmountHelp,
              // Signed: the minus sign is the whole withdrawal mechanism, so
              // this is the one amount field in the app that has to let one
              // through.
              child: MoneyField(
                key: const Key('allocationAmount'),
                controller: _amountController,
                currency: currency,
                allowNegative: true,
                autofocus: true,
                validator: (value) => _parseAmount(value ?? '', locale) == null
                    ? l10n.allocationAmountInvalid
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.allocationDateLabel,
              child: DateField(
                key: const Key('allocationDate'),
                controller: _dateController,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                calendarTooltip: l10n.allocationDatePick,
                validator: (value) =>
                    parseDateInput(value ?? '', locale) == null
                    ? l10n.allocationDateInvalid
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.allocationNoteLabel,
              child: TextFormField(
                key: const Key('allocationNote'),
                controller: _noteController,
                decoration: InputDecoration(hintText: l10n.allocationNoteHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
