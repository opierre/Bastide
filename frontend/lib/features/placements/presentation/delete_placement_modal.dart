import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';

/// Resolves to `true` once the placement has been deleted.
Future<bool?> showDeletePlacementModal(
  BuildContext context, {
  required Investment investment,
}) {
  return showAppModal<bool>(
    context: context,
    builder: (_) => DeletePlacementModal(investment: investment),
  );
}

/// « Supprimer le placement « … » ? » (`17-placements.md` §Modals, proposal
/// v6 `m-investments`): a confirmation without a body whose lead says the
/// values and payments go and the accounts stay; one of the places the solid
/// destructive red may appear. Focus lands on « Annuler ».
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
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      key: const Key('deletePlacementModal'),
      title: l10n.placementDeleteTitle(widget.investment.name),
      width: AppSizes.inspector,
      kind: AppModalKind.destructive,
      busy: _isDeleting,
      subtitle: Text(l10n.placementDeleteLead),
      actions: [
        const AppModalCancel(key: Key('deletePlacementCancel')),
        AppButton(
          key: const Key('deletePlacementSubmit'),
          label: l10n.placementDeleteSubmit,
          variant: AppButtonVariant.destructive,
          isLoading: _isDeleting,
          onPressed: _isDeleting ? null : _confirm,
        ),
      ],
    );
  }
}
