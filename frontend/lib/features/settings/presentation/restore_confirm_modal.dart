import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/date_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/key_value_list.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/backup_controller.dart';
import '../domain/backup.dart';
import 'backup_format.dart';
import 'export_first_action.dart';

/// « Restaurer cette sauvegarde ? » (`09-settings.md` §Données): the file
/// beside the data it would replace, and one of the two places the solid
/// destructive red appears. Nothing is replaced until « Remplacer mes
/// données ».
class RestoreConfirmModal extends ConsumerStatefulWidget {
  const RestoreConfirmModal({super.key, required this.pending});

  final PendingRestore pending;

  @override
  ConsumerState<RestoreConfirmModal> createState() =>
      _RestoreConfirmModalState();
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
        _failure = error is BackupException
            ? error.failure
            : BackupFailure.unknown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final summary = widget.pending.summary;
    final current = ref.watch(currentDataProvider);
    final latestImport = current.value?.lastImportAt;

    return AppModal(
      title: l10n.settingsBackupConfirmTitle,
      width: AppModalSizes.w500,
      kind: AppModalKind.destructive,
      busy: _isRestoring,
      saveError: _failure == null
          ? null
          : backupFailureMessage(l10n, _failure!),
      subtitle: Text(
        l10n.settingsBackupConfirmLead(_longDate(locale, summary.exportedAt)),
        key: const Key('backupConfirmLead'),
      ),
      leadingAction: const ExportFirstAction(),
      actions: [
        const AppModalCancel(),
        AppButton(
          key: const Key('backupConfirmReplace'),
          label: l10n.settingsBackupReplace,
          variant: AppButtonVariant.destructive,
          isLoading: _isRestoring,
          onPressed: _confirm,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.pending.fileName,
            key: const Key('backupConfirmFile'),
            style: context.textStyles.mono.copyWith(color: context.colors.text),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          _Comparison(backup: summary, current: current.value),
          if (current.hasError) ...[
            const SizedBox(height: AppSpacing.fieldGap),
            ModalLoadError(
              message: l10n.settingsBackupConfirmCurrentError,
              onRetry: () => ref.invalidate(currentDataProvider),
            ),
          ] else if (summary.predates(latestImport)) ...[
            const SizedBox(height: AppSpacing.fieldGap),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusText(
                key: const Key('backupConfirmOlder'),
                label: l10n.settingsBackupConfirmOlder(
                  _longDate(locale, latestImport!),
                ),
                tone: StatusTone.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// « 11 mai 2026 », in local time.
String _longDate(String locale, DateTime at) =>
    DayMonthFormat.yMMMMd(locale).format(at.toLocal());

/// « Sauvegarde · Actuel », as the comparison key/value list of `00` §7. The
/// « Actuel » column holds the empty-value dash while it loads, so the
/// modal never reflows under the pointer as the figures arrive.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.backup, required this.current});

  final BackupSummary backup;
  final CurrentData? current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat.decimalPattern(locale);
    // The dash is the empty-value placeholder (`00` §14).
    String date(DateTime? at) => at == null ? '—' : _longDate(locale, at);
    String count(int? value) => value == null ? '—' : number.format(value);
    final now = current?.counts;
    final then = backup.counts;

    return KeyValueComparison(
      key: const Key('backupConfirmSummary'),
      headers: [
        l10n.settingsBackupConfirmBackupColumn,
        l10n.settingsBackupConfirmCurrentColumn,
      ],
      rows: [
        KeyValues(l10n.settingsBackupConfirmVersion, [
          backup.appVersion,
          current?.appVersion ?? '—',
        ]),
        KeyValues(l10n.settingsBackupConfirmLastImport, [
          date(backup.lastImportAt),
          current == null ? '—' : date(current!.lastImportAt),
        ]),
        for (final (label, a, b) in [
          (l10n.settingsBackupConfirmAccounts, then.accounts, now?.accounts),
          (
            l10n.settingsBackupConfirmTransactions,
            then.transactions,
            now?.transactions,
          ),
          (
            l10n.settingsBackupConfirmCategories,
            then.categories,
            now?.categories,
          ),
          (l10n.settingsBackupConfirmRules, then.rules, now?.rules),
          (
            l10n.settingsBackupConfirmSubscriptions,
            then.recurring,
            now?.recurring,
          ),
          (l10n.settingsBackupConfirmGoals, then.goals, now?.goals),
          (l10n.settingsBackupConfirmMortgages, then.mortgages, now?.mortgages),
          (
            l10n.settingsBackupConfirmProperties,
            then.properties,
            now?.properties,
          ),
          (
            l10n.settingsBackupConfirmSimulations,
            then.simulations,
            now?.simulations,
          ),
        ])
          KeyValues(label, [count(a), count(b)]),
      ],
    );
  }
}
