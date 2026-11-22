import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../l10n/app_localizations.dart';
import '../application/backup_controller.dart';

/// « Exporter d’abord », the ghost action on the left of the restore and
/// reset confirmations (`09-settings.md` §Données): it runs the export and its
/// save dialog without closing the modal, then gives way to « Sauvegarde
/// enregistrée » until the modal closes (`00` §7 « Modal », States).
class ExportFirstAction extends ConsumerStatefulWidget {
  const ExportFirstAction({super.key});

  @override
  ConsumerState<ExportFirstAction> createState() => _ExportFirstActionState();
}

class _ExportFirstActionState extends ConsumerState<ExportFirstAction> {
  bool _saved = false;

  Future<void> _export() async {
    try {
      final summary = await ref
          .read(backupControllerProvider.notifier)
          .export();
      // A cancelled save dialog leaves the button as it was.
      if (summary != null && mounted) setState(() => _saved = true);
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        title: AppLocalizations.of(context)!.settingsBackupExportFailed,
        tone: BannerTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isExporting = ref.watch(
      backupControllerProvider.select((state) => state.isExporting),
    );
    return ModalInPlaceAction(
      done: _saved,
      doneLabel: l10n.settingsBackupSaved,
      action: AppButton(
        key: const Key('exportFirstButton'),
        label: l10n.settingsBackupExportFirst,
        icon: LucideIcons300.download,
        variant: AppButtonVariant.ghost,
        isLoading: isExporting,
        onPressed: _export,
      ),
    );
  }
}
