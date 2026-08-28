import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';
import 'goal_labels.dart';

/// Opens the 440 px « Nouvelle allocation » modal over the goal detail. Resolves
/// to the appended line, or `null` when the user cancelled.
Future<GoalAllocation?> showAllocationModal(BuildContext context, {required Goal goal}) {
  return showDialog<GoalAllocation>(
    context: context,
    builder: (_) => AllocationModal(goal: goal),
  );
}

/// One signed amount, a date, and an optional note (`docs/design/11-goals.md`
/// frame ③).
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
    _dateController.text = goalDateFormat(locale).format(DateTime.now());
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
    try {
      final value = NumberFormat.decimalPattern(locale).parse(text.trim());
      final minor = (value.toDouble() * 100).round();
      return minor == 0 ? null : minor;
    } on FormatException {
      return null;
    }
  }

  DateTime? _parseDate(String text, String locale) {
    try {
      return goalDateFormat(locale).parseStrict(text.trim());
    } on FormatException {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final locale = Localizations.localeOf(context).toString();
    final amount = _parseAmount(_amountController.text, locale);
    final date = _parseDate(_dateController.text, locale);
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

    return AppModal(
      title: l10n.allocationModalTitle,
      width: 440,
      actions: [
        OutlinedButton(
          key: const Key('allocationCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.allocationCancel),
        ),
        PrimaryButton(
          key: const Key('allocationSubmit'),
          label: l10n.allocationSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.goal.name,
              key: const Key('allocationGoalName'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorText != null) ...[
              InlineBanner(key: const Key('allocationError'), message: _errorText!),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.allocationAmountLabel,
                    helper: l10n.allocationAmountHelp,
                    child: TextFormField(
                      key: const Key('allocationAmount'),
                      controller: _amountController,
                      autofocus: true,
                      // A signed field: the minus sign is the whole withdrawal
                      // mechanism, so the keyboard has to offer it.
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) => _parseAmount(value ?? '', locale) == null
                          ? l10n.allocationAmountInvalid
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                SizedBox(
                  width: 140,
                  child: LabeledField(
                    label: l10n.allocationDateLabel,
                    child: TextFormField(
                      key: const Key('allocationDate'),
                      controller: _dateController,
                      validator: (value) => _parseDate(value ?? '', locale) == null
                          ? l10n.allocationDateInvalid
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
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
