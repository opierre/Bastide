import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_form.dart';
import '../../accounts/presentation/account_type_label.dart';
import '../application/imports_controller.dart';
import '../application/ofx_account_detection.dart';
import '../domain/csv_template.dart';
import '../domain/import_batch.dart';
import '../domain/ofx_account_info.dart';
import 'csv_mapping_wizard.dart';
import 'import_error_localizer.dart';
import 'import_history.dart';

/// The imports panel: stage a file against an account, import it, and read back
/// what every past import did.
///
/// The account list comes from the accounts feature's controller provider — its
/// published surface, not its internals — because "which account does this
/// statement belong to" is the one question this panel cannot answer alone.
class ImportsScreen extends ConsumerStatefulWidget {
  const ImportsScreen({super.key});

  static const path = '/imports';

  @override
  ConsumerState<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends ConsumerState<ImportsScreen> {
  bool _isImporting = false;
  String? _errorText;

  /// Set when the user explicitly chooses to re-run the wizard for a bank that
  /// already has a saved template. Cleared with the staged file.
  bool _forceWizard = false;

  /// The destination account, resolving the same way the selector renders it:
  /// the explicit choice when there is one, otherwise the first account — which
  /// is what the dropdown shows before the user touches it.
  Account? get _selectedAccount => resolveImportAccount(
    ref.read(accountsControllerProvider).value ?? const <Account>[],
    ref.read(selectedImportAccountProvider),
  );

  Future<void> _pickFile() async {
    final picked = await ref.read(importFilePickerProvider).pick();
    if (picked != null) _stage(picked);
  }

  Future<void> _stage(PickedImportFile file) async {
    setState(() {
      _errorText = null;
      _forceWizard = false;
    });
    ref.read(selectedImportFileProvider.notifier).select(file);
    await _detectAccount(file);
  }

  void _clearFile() {
    setState(() {
      _errorText = null;
      _forceWizard = false;
    });
    ref.read(selectedImportFileProvider.notifier).clear();
    ref.read(ofxAccountDetectionProvider.notifier).clear();
  }

  /// Points the import at the account the statement itself names.
  ///
  /// An OFX file carries its own account block, so the user shouldn't have to
  /// re-state which account a statement is for — and shouldn't be able to file
  /// it against the wrong one by leaving the selector where it was. When no
  /// account matches, the statement is describing an account the user hasn't
  /// created yet, so we offer to create it from what the file says.
  Future<void> _detectAccount(PickedImportFile file) async {
    final List<Account> accounts;
    try {
      accounts = await ref.read(accountsControllerProvider.future);
    } catch (_) {
      // The account selector already reports that the list failed to load;
      // detection just stays silent rather than adding a second error.
      ref.read(ofxAccountDetectionProvider.notifier).clear();
      return;
    }
    // The staged file may have been replaced or cleared while we waited.
    if (!mounted || ref.read(selectedImportFileProvider) != file) return;

    final match = await ref
        .read(ofxAccountDetectionProvider.notifier)
        .detect(file, accounts);
    if (!mounted || ref.read(selectedImportFileProvider) != file) return;

    switch (match) {
      case OfxAccountMatched(:final account):
        ref.read(selectedImportAccountProvider.notifier).select(account.id);
      case OfxAccountUnmatched(:final info):
        await _createDetectedAccount(info);
      case OfxAccountAmbiguous() || null:
        break;
    }
  }

  /// Opens the account form pre-filled from the statement, and imports into the
  /// account it creates. Cancelling leaves the banner and its button in place,
  /// so the offer can be taken up later.
  Future<void> _createDetectedAccount(OfxAccountInfo info) async {
    final l10n = AppLocalizations.of(context)!;
    final created = await showAccountForm(context, prefill: _prefillFrom(info, l10n));
    if (created == null || !mounted) return;
    ref.read(selectedImportAccountProvider.notifier).select(created.id);
    ref.read(ofxAccountDetectionProvider.notifier).resolveTo(info, created);
  }

  /// Routes the staged file: OFX/QFX import in one step, CSV either through the
  /// saved template for that bank or through the mapping wizard.
  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final account = _selectedAccount;
    final file = ref.read(selectedImportFileProvider);
    if (account == null || file == null) return;

    final template = file.needsCsvTemplate && !_forceWizard
        ? ref.read(csvTemplatesControllerProvider.notifier).templateFor(account.institution)
        : null;

    if (file.needsCsvTemplate && template == null) {
      final batch = await showCsvMappingWizard(
        context,
        accountId: account.id,
        institution: account.institution,
        file: file,
        currency: account.currency,
      );
      if (batch != null) _finish(batch);
      return;
    }

    setState(() {
      _isImporting = true;
      _errorText = null;
    });

    try {
      final batch = await ref
          .read(importsControllerProvider.notifier)
          .importFile(
            accountId: account.id,
            file: file,
            csvTemplateId: template?.id,
          );
      _finish(batch);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = localizeImportError(l10n, error));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Clears the drop zone and promotes the batch to the result card. Runs for a
  /// `failed` batch too — the file was handled, and its outcome belongs in the
  /// result card rather than as an error over the drop zone.
  void _finish(ImportBatch batch) {
    if (!mounted) return;
    ref.read(lastImportResultProvider.notifier).set(batch);
    ref.read(selectedImportFileProvider.notifier).clear();
    ref.read(ofxAccountDetectionProvider.notifier).clear();
    setState(() => _forceWizard = false);
  }

  @override
  Widget build(BuildContext context) {
    final lastResult = ref.watch(lastImportResultProvider);

    return Padding(
      key: const Key('screen-imports'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 135,
                  child: _NewImportCard(
                    isImporting: _isImporting,
                    errorText: _errorText,
                    forceWizard: _forceWizard,
                    onPickFile: _pickFile,
                    onDropFile: _stage,
                    onClearFile: _clearFile,
                    onImport: _import,
                    onCreateDetectedAccount: _createDetectedAccount,
                    onReconfigure: () => setState(() => _forceWizard = true),
                  ),
                ),
                if (lastResult != null) ...[
                  const SizedBox(width: AppSpacing.gridGap),
                  Expanded(flex: 100, child: _ResultCard(batch: lastResult)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gridGap),
          const Expanded(child: ImportHistory()),
        ],
      ),
    );
  }
}

/// The statement's account phrased for the account form: a name built from the
/// type and the last digits of the account number, plus the bank's own name for
/// itself. Everything stays editable — the user renames it if they prefer.
AccountPrefill _prefillFrom(OfxAccountInfo info, AppLocalizations l10n) {
  final type = accountTypeFromOfx(info.accountType);
  final label = type == null ? info.institutionLabel : accountTypeLabel(l10n, type);
  return AccountPrefill(
    name: [?label, info.maskedNumber].join(' '),
    institution: info.institutionLabel,
    type: type,
    // Bound to the account so the next statement from it matches on identity
    // rather than on how the bank happens to spell its own name.
    ofxAccountId: info.accountNumber.trim(),
  );
}

/// How a detected account is named in the banners: `Boursorama ••4567`, or just
/// the masked number when the file names no bank.
String _detectedAccountLabel(OfxAccountInfo info) =>
    [?info.institutionLabel, info.maskedNumber].join(' ');

/// Resolves the selected account id against the loaded list, falling back to
/// the first account so the common single-account case needs no selection at
/// all. Shared by the selector, the staged-file row and the import action, so
/// what is shown and what is imported into can't diverge.
Account? resolveImportAccount(List<Account> accounts, String? selectedId) {
  if (accounts.isEmpty) return null;
  for (final account in accounts) {
    if (account.id == selectedId) return account;
  }
  return accounts.first;
}

/// Region A — destination account plus the drop zone.
class _NewImportCard extends ConsumerWidget {
  const _NewImportCard({
    required this.isImporting,
    required this.errorText,
    required this.forceWizard,
    required this.onPickFile,
    required this.onDropFile,
    required this.onClearFile,
    required this.onImport,
    required this.onCreateDetectedAccount,
    required this.onReconfigure,
  });

  final bool isImporting;
  final String? errorText;
  final bool forceWizard;
  final VoidCallback onPickFile;
  final ValueChanged<PickedImportFile> onDropFile;
  final VoidCallback onClearFile;
  final VoidCallback onImport;
  final ValueChanged<OfxAccountInfo> onCreateDetectedAccount;
  final VoidCallback onReconfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsControllerProvider);
    final file = ref.watch(selectedImportFileProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.importNewTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          switch (accounts) {
            // Nothing to select from, and nothing to say: a statement now
            // proposes the account it belongs to, so having no accounts yet is
            // not something the user has to fix before dropping a file.
            AsyncData(:final value) when value.isEmpty => const SizedBox.shrink(),
            AsyncData(:final value) => _AccountSelect(accounts: value),
            AsyncError() => InlineBanner(
              key: const Key('importAccountsErrorBanner'),
              message: l10n.importAccountsUnavailable,
            ),
            _ => const SkeletonBlock(height: 44, radius: AppRadii.md),
          },
          _DetectedAccountNotice(
            isImporting: isImporting,
            onCreateAccount: onCreateDetectedAccount,
          ),
          const SizedBox(height: AppSpacing.md),
          if (file == null)
            _DropZone(onPickFile: onPickFile, onDropFile: onDropFile)
          else
            _StagedFile(
              file: file,
              isImporting: isImporting,
              forceWizard: forceWizard,
              onClear: onClearFile,
              onImport: onImport,
              onReconfigure: onReconfigure,
            ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(key: const Key('importErrorBanner'), message: errorText!),
          ],
        ],
      ),
    );
  }
}

/// What the staged statement says about its own account, sitting right under
/// the destination selector it either settled or is questioning.
///
/// Renders nothing at all when there is nothing to say — no file staged, a CSV
/// (which declares no account), or an OFX whose header we couldn't read.
class _DetectedAccountNotice extends ConsumerWidget {
  const _DetectedAccountNotice({
    required this.isImporting,
    required this.onCreateAccount,
  });

  final bool isImporting;
  final ValueChanged<OfxAccountInfo> onCreateAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final match = ref.watch(ofxAccountDetectionProvider);
    if (match == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: switch (match) {
        OfxAccountMatched(:final account) => InlineBanner(
          key: const Key('importDetectedAccountBanner'),
          message: l10n.importDetectedAccount(account.name),
          tone: BannerTone.success,
        ),
        OfxAccountAmbiguous(:final info) => InlineBanner(
          key: const Key('importAmbiguousAccountBanner'),
          message: l10n.importDetectedAccountAmbiguous(_detectedAccountLabel(info)),
          tone: BannerTone.warning,
        ),
        OfxAccountUnmatched(:final info) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InlineBanner(
              key: const Key('importUnknownAccountBanner'),
              message: l10n.importDetectedAccountUnknown(_detectedAccountLabel(info)),
              tone: BannerTone.warning,
            ),
            TextButton(
              key: const Key('importCreateDetectedAccountButton'),
              onPressed: isImporting ? null : () => onCreateAccount(info),
              child: Text(l10n.importCreateDetectedAccount),
            ),
          ],
        ),
      },
    );
  }
}

class _AccountSelect extends ConsumerWidget {
  const _AccountSelect({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedId = ref.watch(selectedImportAccountProvider);
    final value = resolveImportAccount(accounts, selectedId)?.id;

    return LabeledField(
      label: l10n.importAccountLabel,
      child: DropdownButtonFormField<String>(
        key: const Key('importAccountField'),
        initialValue: value,
        borderRadius: BorderRadius.circular(AppRadii.md),
        icon: const Icon(Icons.expand_more_rounded, size: 18),
        isExpanded: true,
        items: [
          for (final account in accounts)
            DropdownMenuItem(
              value: account.id,
              child: Row(
                children: [
                  InstitutionAvatar(name: account.institution, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(account.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (selected) =>
            ref.read(selectedImportAccountProvider.notifier).select(selected),
      ),
    );
  }
}

/// The empty drop zone: a dashed plate that accepts both a dropped file and a
/// click through to the native browse dialog.
class _DropZone extends StatefulWidget {
  const _DropZone({required this.onPickFile, required this.onDropFile});

  final VoidCallback onPickFile;
  final ValueChanged<PickedImportFile> onDropFile;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _dragging = false;

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    if (details.files.isEmpty) return;
    final dropped = details.files.first;
    widget.onDropFile(
      PickedImportFile(name: dropped.name, bytes: await dropped.readAsBytes()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('importDropZone'),
          onTap: widget.onPickFile,
          child: DashedBorder(
            color: _dragging ? AppColors.iris : AppColors.borderDashed,
            radius: AppRadii.inset,
            strokeWidth: 1.5,
            child: Container(
              height: 168,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _dragging ? const Color(0x128B8CF9) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.inset),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GlyphPlate(icon: Icons.download_outlined),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.importDropZoneTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.importDropZoneHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.helper,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The file-selected variant: what is staged, and the one action that commits it.
class _StagedFile extends ConsumerWidget {
  const _StagedFile({
    required this.file,
    required this.isImporting,
    required this.forceWizard,
    required this.onClear,
    required this.onImport,
    required this.onReconfigure,
  });

  final PickedImportFile file;
  final bool isImporting;
  final bool forceWizard;
  final VoidCallback onClear;
  final VoidCallback onImport;
  final VoidCallback onReconfigure;

  /// The saved mapping that would be reused for this file, if any.
  CsvTemplate? _reusableTemplate(WidgetRef ref) {
    if (!file.needsCsvTemplate || forceWizard) return null;
    final accounts = ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final account = resolveImportAccount(
      accounts,
      ref.watch(selectedImportAccountProvider),
    );
    if (account == null) return null;
    // Watched so a template saved by the wizard is picked up immediately.
    ref.watch(csvTemplatesControllerProvider);
    return ref
        .read(csvTemplatesControllerProvider.notifier)
        .templateFor(account.institution);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final template = _reusableTemplate(ref);
    final format = ImportFormat.fromWire(file.extension);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashedBorder(
          color: AppColors.iris,
          radius: AppRadii.inset,
          strokeWidth: 1.5,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0x148B8CF9),
              borderRadius: BorderRadius.circular(AppRadii.inset),
            ),
            child: Row(
              children: [
                ImportFormatBadge(format: format),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        key: const Key('importStagedFileName'),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.importFileSize(_formatKilobytes(file.bytes.length, locale)),
                        style: AppTextStyles.helper,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('importRemoveFileButton'),
                  onPressed: isImporting ? null : onClear,
                  tooltip: l10n.importRemoveFile,
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
          ),
        ),
        if (template != null) ...[
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          InlineBanner(
            key: const Key('importTemplateReuseBanner'),
            message: l10n.importTemplateReuse(template.bankName),
            tone: BannerTone.info,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (template != null)
              TextButton(
                key: const Key('importReconfigureButton'),
                onPressed: isImporting ? null : onReconfigure,
                child: Text(l10n.importReconfigureTemplate),
              ),
            const SizedBox(width: AppSpacing.sm),
            PrimaryButton(
              key: const Key('importSubmitButton'),
              label: file.needsCsvTemplate && template == null
                  ? l10n.importOpenWizard
                  : l10n.importSubmit,
              loadingLabel: l10n.importSubmitting,
              isLoading: isImporting,
              height: 42,
              onPressed: onImport,
            ),
          ],
        ),
      ],
    );
  }
}

String _formatKilobytes(int bytes, String locale) =>
    NumberFormat('#,##0.#', locale).format(bytes / 1024);

/// Region A' — what the import that just ran actually did.
class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.batch});

  final ImportBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final account = accounts.where((account) => account.id == batch.accountId).firstOrNull;
    final accountName = account?.name;

    return AppCard(
      key: const Key('importResultCard'),
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.importResultTitle, style: textTheme.titleMedium),
              ),
              ImportStatusPill(status: batch.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (batch.status == ImportStatus.failed) ...[
            InlineBanner(
              key: const Key('importResultFailure'),
              message: l10n.importFailedNote,
            ),
            if (batch.errorMessage case final message? when message.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: AppTextStyles.mono),
            ],
          ] else
            Row(
              children: [
                Expanded(
                  child: _CountPlate(
                    valueKey: const Key('importResultNewCount'),
                    value: batch.newCount,
                    label: l10n.importResultNewLabel(batch.newCount),
                    color: AppColors.positive,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: _CountPlate(
                    valueKey: const Key('importResultDuplicateCount'),
                    value: batch.duplicateCount,
                    label: l10n.importResultDuplicateLabel(batch.duplicateCount),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          if (batch.balanceMismatchMinor case final mismatch?) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: const Key('importResultBalanceMismatch'),
              message: l10n.importResultBalanceMismatchBody(
                formatAmount(
                  amountMinor: mismatch,
                  currency: account?.currency ?? '',
                  locale: Localizations.localeOf(context).toString(),
                  showPositiveSign: true,
                ),
                batch.balanceMismatchAsOf!,
              ),
              tone: BannerTone.warning,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.importPeriodRange(batch.periodStart, batch.periodEnd),
            key: const Key('importResultPeriod'),
            style: tabularNumberStyle(
              textTheme.bodySmall!,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            accountName == null
                ? batch.fileName
                : l10n.importResultTarget(batch.fileName, accountName),
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.helper,
          ),
        ],
      ),
    );
  }
}

/// An inset plate carrying one count from the run.
class _CountPlate extends StatelessWidget {
  const _CountPlate({
    required this.valueKey,
    required this.value,
    required this.label,
    required this.color,
  });

  final Key valueKey;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppRadii.inset),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            NumberFormat.decimalPattern(locale).format(value),
            key: valueKey,
            style: tabularNumberStyle(
              Theme.of(context).textTheme.headlineLarge!,
            ).copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.helper),
        ],
      ),
    );
  }
}
