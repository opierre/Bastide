import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';

/// Width of the goal modals (`11-goals.md` §Modals).
const _modalWidth = 440.0;

/// Opens « Supprimer cette allocation ? » over the inspector.
Future<void> showDeleteAllocationModal(
  BuildContext context, {
  required Goal goal,
  required GoalAllocation allocation,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => DeleteAllocationModal(goal: goal, allocation: allocation),
  );
}

/// The confirmation before a ledger line goes: it states by how much the
/// saved total moves, and it is one of the places the solid destructive red
/// may appear.
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
    final amountMinor = widget.allocation.amountMinor;
    final amount = formatAmount(
      amountMinor: amountMinor.abs(),
      currency: widget.goal.currency,
      locale: Localizations.localeOf(context).toString(),
    );

    return AppModal(
      key: const Key('goalAllocationDeleteModal'),
      title: l10n.goalAllocationDeleteTitle,
      width: _modalWidth,
      subtitle: Text(
        amountMinor >= 0
            ? l10n.goalAllocationDeleteLeadDown(amount)
            : l10n.goalAllocationDeleteLeadUp(amount),
        key: const Key('goalAllocationDeleteLead'),
      ),
      actions: [
        AppButton(
          key: const Key('goalAllocationDeleteCancel'),
          label: l10n.goalAllocationDeleteCancel,
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          key: const Key('goalAllocationDeleteSubmit'),
          label: l10n.goalAllocationDeleteSubmit,
          variant: AppButtonVariant.destructive,
          isLoading: _isDeleting,
          onPressed: _isDeleting ? null : _confirm,
        ),
      ],
      child: const SizedBox.shrink(),
    );
  }
}
