import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/backup_controller.dart';
import '../application/settings_controller.dart';
import 'backup_format.dart';
import 'restore_confirm_modal.dart';
import 'setting_row.dart';

/// « Sauvegarde » in Settings › Données: export everything, or restore a
/// backup (`docs/design/09-settings.md` §Données).
///
/// The destructive red never appears here, only in the confirmation modal a
/// restore always goes through.
class BackupGroup extends ConsumerWidget {
  const BackupGroup({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    try {
      final summary = await ref
          .read(backupControllerProvider.notifier)
          .export();
      if (summary == null || !context.mounted) return;
      final counts = summary.counts;
      showAppToast(
        context,
        title: l10n.settingsBackupExported(
          counts.transactions,
          number.format(counts.transactions),
          counts.accounts,
          number.format(counts.accounts),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(
        context,
        title: l10n.settingsBackupExportFailed,
        tone: BannerTone.error,
      );
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final pending = await ref
        .read(backupControllerProvider.notifier)
        .pickForRestore();
    if (pending == null || !context.mounted) return;
    await showAppModal<void>(
      context: context,
      builder: (_) => RestoreConfirmModal(pending: pending),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(backupControllerProvider);
    final (loaded, lastBackupAt) = ref.watch(
      settingsControllerProvider.select(
        (value) => (value.hasValue, value.value?.settings.lastBackupAt),
      ),
    );

    return Column(
      key: const Key('settingsBackupCard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(title: l10n.settingsBackupTitle),
        SettingRow(
          key: const Key('settingsBackupExportRow'),
          name: l10n.settingsBackupExportLabel,
          description: l10n.settingsBackupExportCaption,
          children: [
            // Loading keeps the button's width and refuses a second click:
            // it would start a second export.
            PrimaryButton(
              key: const Key('settingsBackupExportButton'),
              label: l10n.settingsBackupExport,
              loadingLabel: l10n.settingsBackupExportPreparing,
              icon: LucideIcons300.download,
              isLoading: state.isExporting,
              onPressed: () => _export(context, ref),
            ),
            // The line waits for the settings it reads: « no backup » shown
            // while loading would be a claim about a value not known yet.
            if (loaded)
              Text(
                lastBackupAt == null
                    ? l10n.settingsBackupNone
                    : l10n.settingsBackupLast(
                        formatBackupInstant(
                          l10n,
                          Localizations.localeOf(context).toString(),
                          lastBackupAt,
                        ),
                      ),
                key: const Key('settingsBackupLast'),
                style: tabularNumberStyle(
                  Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
        SettingRow(
          key: const Key('settingsBackupRestoreRow'),
          name: l10n.settingsBackupRestoreTitle,
          description: l10n.settingsBackupRestoreSubtitle,
          children: [
            AppButton(
              key: const Key('settingsBackupRestoreButton'),
              label: l10n.settingsBackupRestoreButton,
              icon: LucideIcons300.upload,
              onPressed: state.isPicking ? null : () => _restore(context, ref),
            ),
            // A file refused before anything was touched, a newer version's
            // chiefly, is reported under the row that picked it.
            if (state.restoreFailure case final failure?)
              InlineBanner(
                key: const Key('settingsBackupRestoreError'),
                message: l10n.settingsBackupRestoreRefused(
                  backupFailureMessage(l10n, failure),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
