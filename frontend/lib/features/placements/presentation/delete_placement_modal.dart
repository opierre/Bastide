import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';

Future<void> showDeletePlacementModal(
  BuildContext context, {
  required Investment investment,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => DeletePlacementModal(investment: investment),
  );
}

/// The confirmation before a placement goes with its whole history
/// (`17-placements.md` §Behaviour). It says so, and points at closing as the
/// way to keep it; one of the places the solid destructive red may appear.
class DeletePlacementModal extends ConsumerStatefulWidget {
  const DeletePlacementModal({super.key, required this.investment});

  final Investment investment;

  @override
  ConsumerState<DeletePlacementModal> createState() =>
      _DeletePlacementModalState();
}

class _DeletePlacementModalState extends ConsumerState<DeletePlacementModal> {
  bool _isDeleting = false;

  Future<void> _confirm() async {
    setState(() => _isDeleting = true);
    // A refusal lands in the panel's banner, so the modal closes either way.
    await ref
        .read(placementsControllerProvider.notifier)
        .delete(widget.investment.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      key: const Key('deletePlacementModal'),
      title: l10n.placementDeleteTitle,
      width: AppSizes.inspector,
      subtitle: Text(l10n.placementDeleteLead(widget.investment.name)),
      actions: [
        AppButton(
          key: const Key('deletePlacementCancel'),
          label: l10n.placementFormCancel,
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          key: const Key('deletePlacementSubmit'),
          label: l10n.placementDeleteSubmit,
          variant: AppButtonVariant.destructive,
          isLoading: _isDeleting,
          onPressed: _isDeleting ? null : _confirm,
        ),
      ],
      child: const SizedBox.shrink(),
    );
  }
}
