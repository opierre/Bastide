import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';

/// Resolves to `true` once the goal has been deleted.
Future<bool?> showDeleteGoalModal(BuildContext context, {required Goal goal}) {
  return showAppModal<bool>(
    context: context,
    builder: (_) => DeleteGoalModal(goal: goal),
  );
}

/// « Supprimer l’objectif « … » ? », opened from the edit modal's ghost
/// « Supprimer », as a placement is deleted (`17-placements.md` §Modals): a
/// destructive confirmation without a body whose lead says the allocations
/// and the image go, that archiving keeps them, and that the accounts stay;
/// one of the places the solid destructive red may appear. Focus lands on
/// « Annuler ».
class DeleteGoalModal extends ConsumerStatefulWidget {
  const DeleteGoalModal({super.key, required this.goal});

  final Goal goal;

  @override
  ConsumerState<DeleteGoalModal> createState() => _DeleteGoalModalState();
}

class _DeleteGoalModalState extends ConsumerState<DeleteGoalModal> {
  bool _isDeleting = false;

  Future<void> _confirm() async {
    setState(() => _isDeleting = true);
    // A refusal lands in the panel's banner, so the modal closes either way.
    await ref.read(goalsControllerProvider.notifier).delete(widget.goal.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      key: const Key('goalDeleteModal'),
      title: l10n.goalDeleteTitle(widget.goal.name),
      width: AppModalSizes.w440,
      kind: AppModalKind.destructive,
      busy: _isDeleting,
      subtitle: Text(l10n.goalDeleteLead, key: const Key('goalDeleteLead')),
      actions: [
        const AppModalCancel(key: Key('goalDeleteCancel')),
        AppButton(
          key: const Key('goalDeleteSubmit'),
          label: l10n.goalDeleteSubmit,
          variant: AppButtonVariant.destructive,
          isLoading: _isDeleting,
          onPressed: _isDeleting ? null : _confirm,
        ),
      ],
    );
  }
}
