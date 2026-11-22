import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';

/// Opens « Supprimer l’allocation du … ? » over the inspector.
Future<void> showDeleteAllocationModal(
  BuildContext context, {
  required Goal goal,
  required GoalAllocation allocation,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => DeleteAllocationModal(goal: goal, allocation: allocation),
  );
}

/// « Supprimer l’allocation du 1er mai 2026 ? » (`11-goals.md` §Modals,
/// proposal v6 `m-goals`): a destructive confirmation without a body. The
/// title names the line by its date, the lead names the goal and by how much
/// its saved total moves; one of the places the solid destructive red may
/// appear. Focus lands on « Annuler ».
///
/// A withdrawal is a negative line, so deleting one makes the total go back
/// up: the lead says which way, rather than claiming it always goes down.
class DeleteAllocationModal extends ConsumerStatefulWidget {
  const DeleteAllocationModal({
    super.key,
    required this.goal,
    required this.allocation,
  });

  final Goal goal;
  final GoalAllocation allocation;

  @override
  ConsumerState<DeleteAllocationModal> createState() =>
      _DeleteAllocationModalState();
}

class _DeleteAllocationModalState extends ConsumerState<DeleteAllocationModal> {
  bool _isDeleting = false;

  Future<void> _confirm() async {
    setState(() => _isDeleting = true);
    // A refusal lands in the panel's banner (the controller keeps the table
    // standing), so the modal closes either way.
    await ref
        .read(goalsControllerProvider.notifier)
        .deleteAllocation(widget.goal.id, widget.allocation.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final amountMinor = widget.allocation.amountMinor;
    final amount = formatAmount(
      amountMinor: amountMinor.abs(),
      currency: widget.goal.currency,
      locale: locale,
    );
    final on = widget.allocation.allocatedOn;
    final date = l10n.goalAllocationDeleteDate(
      on.day,
      DateFormat.MMMM(locale).format(on),
      DateFormat.y(locale).format(on),
    );
    final goal = widget.goal.name;

    return AppModal(
      key: const Key('goalAllocationDeleteModal'),
      title: l10n.goalAllocationDeleteTitle(date),
      width: AppModalSizes.w440,
      kind: AppModalKind.destructive,
      busy: _isDeleting,
      subtitle: Text(
        amountMinor >= 0
            ? l10n.goalAllocationDeleteLeadDown(goal, amount)
            : l10n.goalAllocationDeleteLeadUp(goal, amount),
        key: const Key('goalAllocationDeleteLead'),
      ),
      actions: [
        const AppModalCancel(key: Key('goalAllocationDeleteCancel')),
        AppButton(
          key: const Key('goalAllocationDeleteSubmit'),
          label: l10n.goalAllocationDeleteSubmit,
          variant: AppButtonVariant.destructive,
          isLoading: _isDeleting,
          onPressed: _isDeleting ? null : _confirm,
        ),
      ],
    );
  }
}
