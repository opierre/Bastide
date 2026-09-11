import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/backup_controller.dart';
import '../application/settings_controller.dart';
import 'backup_format.dart';
import 'lock_callout.dart';
import 'refusal_banner.dart';
import 'restore_confirm_modal.dart';

/// The « Sauvegarde et restauration » card in Settings › Données
/// (`docs/design/09-settings.md` §Sauvegarde et restauration, states ⑤–⑨).
///
/// The destructive red never appears here — only in the confirmation modal a
/// restore always goes through.
class BackupCard extends ConsumerWidget {
  const BackupCard({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    try {
      final summary = await ref.read(backupControllerProvider.notifier).export();
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
      showAppToast(context, title: l10n.settingsBackupExportFailed, tone: BannerTone.error);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final pending = await ref.read(backupControllerProvider.notifier).pickForRestore();
    if (pending == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => RestoreConfirmModal(pending: pending),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(backupControllerProvider);
    final (loaded, lastBackupAt) = ref.watch(
      settingsControllerProvider.select(
        (value) => (value.hasValue, value.value?.settings.lastBackupAt),
      ),
    );

    return AppCard(
      key: const Key('settingsBackupCard'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsBackupTitle, style: textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            l10n.settingsBackupSubtitle,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _ExportPlate(
            isExporting: state.isExporting,
            onExport: () => _export(context, ref),
          ),
          // The line waits for the settings it reads — « no backup yet » shown
          // while loading would be a claim about a value not known yet.
          if (loaded) ...[
            const SizedBox(height: AppSpacing.sm - 2),
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
                AppTextStyles.helper.copyWith(fontSize: 11.5, color: AppColors.textDisabled),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // ⑨: the refusal takes the callout's place rather than stacking under
          // it. One plate holds this slot, and while a file has just been
          // refused, why it was refused outranks a standing notice.
          if (state.restoreFailure != null)
            RefusalBanner(
              key: const Key('settingsBackupRestoreError'),
              lead: l10n.settingsBackupRestoreFailedLead,
              message: backupFailureMessage(l10n, state.restoreFailure!),
            )
          else
            LockCallout(
              key: const Key('settingsBackupPrivacy'),
              message: l10n.settingsBackupPrivacy,
            ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          _RestoreRow(
            isBusy: state.isPicking,
            onPick: () => _restore(context, ref),
          ),
        ],
      ),
    );
  }
}

/// The inset export plate: tile, label and caption, and the primary button.
class _ExportPlate extends StatelessWidget {
  const _ExportPlate({required this.isExporting, required this.onExport});

  final bool isExporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    final button = PrimaryButton(
      key: const Key('settingsBackupExportButton'),
      label: l10n.settingsBackupExport,
      height: 34,
      isLoading: isExporting,
      onPressed: onExport,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.inset),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.irisSoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(Icons.file_download_outlined, size: 18, color: AppColors.iris),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsBackupExportLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isExporting
                      ? l10n.settingsBackupExportPreparing
                      : l10n.settingsBackupExportCaption,
                  key: const Key('settingsBackupExportCaption'),
                  style: AppTextStyles.helper.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          // ⑥: dimmed and refusing the pointer while the archive is prepared —
          // a second click would start a second export.
          if (isExporting)
            MouseRegion(
              cursor: SystemMouseCursors.forbidden,
              child: IgnorePointer(child: Opacity(opacity: 0.55, child: button)),
            )
          else
            button,
        ],
      ),
    );
  }
}

class _RestoreRow extends StatelessWidget {
  const _RestoreRow({required this.isBusy, required this.onPick});

  final bool isBusy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsBackupRestoreTitle,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.settingsBackupRestoreSubtitle,
                style: AppTextStyles.helper.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            key: const Key('settingsBackupRestoreButton'),
            onPressed: isBusy ? null : onPick,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs),
              ),
            ),
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: Text(l10n.settingsBackupRestoreButton),
          ),
        ),
      ],
    );
  }
}

