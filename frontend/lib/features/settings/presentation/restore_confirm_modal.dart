import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/backup_controller.dart';
import '../domain/backup.dart';
import 'backup_format.dart';

/// State ⑧: what the chosen file holds, and the one place the destructive red
/// appears. Nothing is replaced until « Remplacer mes données ».
class RestoreConfirmModal extends ConsumerStatefulWidget {
  const RestoreConfirmModal({super.key, required this.pending});

  final PendingRestore pending;

  @override
  ConsumerState<RestoreConfirmModal> createState() => _RestoreConfirmModalState();
}

class _RestoreConfirmModalState extends ConsumerState<RestoreConfirmModal> {
  bool _isRestoring = false;
  BackupFailure? _failure;

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isRestoring = true;
      _failure = null;
    });
    try {
      await ref.read(backupControllerProvider.notifier).restore(widget.pending);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppToast(context, title: l10n.settingsBackupRestored);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _failure = error is BackupException ? error.failure : BackupFailure.unknown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppModal(
      title: l10n.settingsBackupConfirmTitle,
      width: 500,
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${l10n.settingsBackupConfirmFile} '),
            TextSpan(
              text: widget.pending.fileName,
              style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        key: const Key('backupConfirmFile'),
        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isRestoring ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settingsBackupCancel),
        ),
        FilledButton(
          key: const Key('backupConfirmReplace'),
          onPressed: _isRestoring ? null : _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.negative,
            foregroundColor: AppColors.negativeInk,
            disabledBackgroundColor: AppColors.negative.withValues(alpha: 0.55),
            disabledForegroundColor: AppColors.negativeInk,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRestoring) ...[
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.negativeInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(l10n.settingsBackupReplace),
            ],
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failure != null) ...[
            InlineBanner(
              key: const Key('backupConfirmError'),
              message: backupFailureMessage(l10n, _failure!),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _SummaryPlate(summary: widget.pending.summary),
          const SizedBox(height: AppSpacing.md),
          InlineBanner(
            key: const Key('backupConfirmWarning'),
            tone: BannerTone.warning,
            message: l10n.settingsBackupConfirmWarning,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _SummaryPlate extends StatelessWidget {
  const _SummaryPlate({required this.summary});

  final BackupSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat.decimalPattern(locale);
    final counts = summary.counts;
    final valueStyle = tabularNumberStyle(
      Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textPrimary),
    );

    final rows = <(String, Widget)>[
      (
        l10n.settingsBackupConfirmExportedAt,
        Text(formatBackupInstant(l10n, locale, summary.exportedAt), style: valueStyle),
      ),
      (
        l10n.settingsBackupConfirmVersion,
        Text(
          summary.appVersion,
          style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
        ),
      ),
      for (final (label, count) in [
        (l10n.settingsBackupConfirmAccounts, counts.accounts),
        (l10n.settingsBackupConfirmTransactions, counts.transactions),
        (l10n.settingsBackupConfirmCategories, counts.categories),
        (l10n.settingsBackupConfirmRules, counts.rules),
        (l10n.settingsBackupConfirmSubscriptions, counts.recurring),
        (l10n.settingsBackupConfirmGoals, counts.goals),
        (l10n.settingsBackupConfirmMortgages, counts.mortgages),
        (l10n.settingsBackupConfirmProperties, counts.properties),
        (l10n.settingsBackupConfirmSimulations, counts.simulations),
      ])
        (label, Text(number.format(count), style: valueStyle)),
    ];

    return Container(
      key: const Key('backupConfirmSummary'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.inset),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  // Expanded, not a Spacer: the longest label (« Paramètres fiscaux
                  // personnalisés ») must shrink on a narrow modal, never overflow.
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  value,
                ],
              ),
            ),
        ],
      ),
    );
  }
}
