import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select.dart';
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
import '../domain/import_batch.dart';
import '../domain/ofx_account_info.dart';
import 'import_error_localizer.dart';
import 'import_history.dart';

/// The imports panel: stage a statement, import it, and read back what every
/// past import did.
///
/// There is no destination field. An OFX file carries its own account block, so
/// the panel reads the destination out of the file and only asks when the file
/// leaves the question genuinely open — see [OfxAccountMatch].
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

  /// Where each statement of the file will land.
  ///
  /// Read from the statements themselves, falling back to the account the user
  /// picked only when a statement couldn't name one (see
  /// [resolveImportTargets]). There is deliberately no default: with the
  /// destination selector gone, an unresolved destination leaves the import
  /// button disabled rather than filing a statement somewhere nobody chose.
  List<ImportTarget>? get _targets => resolveImportTargets(
    ref.read(ofxAccountDetectionProvider),
    ref.read(chosenImportAccountsProvider),
    ref.read(accountsControllerProvider).value ?? const <Account>[],
  );

  Future<void> _pickFile() async {
    final picked = await ref.read(importFilePickerProvider).pick();
    if (picked != null) _stage(picked);
  }

  Future<void> _stage(PickedImportFile file) async {
    setState(() => _errorText = null);
    // A choice made for the previous file says nothing about this one.
    ref.read(chosenImportAccountsProvider.notifier).clear();
    ref.read(selectedImportFileProvider.notifier).select(file);
    await _detectAccount(file);
  }

  void _clearFile() {
    setState(() => _errorText = null);
    ref.read(selectedImportFileProvider.notifier).clear();
    ref.read(ofxAccountDetectionProvider.notifier).clear();
    ref.read(chosenImportAccountsProvider.notifier).clear();
  }

  /// Points each statement at the account it names.
  ///
  /// An OFX file carries its own account blocks, so the panel reads the
  /// destinations out of the file rather than asking for them. A statement no
  /// account matches describes an account the user hasn't created yet, so we
  /// offer to create each in turn from what the file says; when the file can't
  /// settle one alone, `_DetectedAccountNotice` asks.
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

    final matches = await ref
        .read(ofxAccountDetectionProvider.notifier)
        .detect(file, accounts);

    // Matched needs nothing — the verdict *is* the destination. The two
    // unresolved cases are put to the user by `_DetectedAccountNotice` rather
    // than answered here.
    for (final match in matches) {
      if (!mounted || ref.read(selectedImportFileProvider) != file) return;
      if (match case OfxAccountUnmatched(:final info)) {
        await _createDetectedAccount(info);
      }
    }
  }

  /// Opens the account form pre-filled from the statement, and imports into the
  /// account it creates. Cancelling leaves the banner and its button in place,
  /// so the offer can be taken up later.
  Future<void> _createDetectedAccount(OfxAccountInfo info) async {
    final l10n = AppLocalizations.of(context)!;
    final created = await showAccountForm(
      context,
      prefill: _prefillFrom(info, l10n),
    );
    if (created == null || !mounted) return;
    ref.read(ofxAccountDetectionProvider.notifier).resolveTo(info, created);
  }

  /// Uploads each statement of the staged file into the account it resolved to.
  ///
  /// One request per statement, in file order. A failure part-way leaves the
  /// file staged and shows what did land: retrying is safe, since a statement
  /// already imported into its account comes back as its original batch.
  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final targets = _targets;
    final file = ref.read(selectedImportFileProvider);
    if (targets == null || file == null) return;

    setState(() {
      _isImporting = true;
      _errorText = null;
    });

    final batches = <ImportBatch>[];
    try {
      for (final target in targets) {
        batches.add(
          await ref
              .read(importsControllerProvider.notifier)
              .importFile(
                accountId: target.account.id,
                file: file,
                statement: target.statement,
              ),
        );
      }
      _finish(batches);
    } catch (error) {
      if (!mounted) return;
      final message = localizeImportError(l10n, error);
      if (batches.isNotEmpty) {
        ref.read(lastImportResultProvider.notifier).set(batches);
      }
      setState(
        () => _errorText = batches.isEmpty
            ? message
            : l10n.importErrorPartial(batches.length, targets.length, message),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Clears the drop zone and promotes the batches to the result card. Runs for
  /// `failed` batches too — the file was handled, and its outcome belongs in
  /// the result card rather than as an error over the drop zone.
  void _finish(List<ImportBatch> batches) {
    if (!mounted) return;
    ref.read(lastImportResultProvider.notifier).set(batches);
    ref.read(selectedImportFileProvider.notifier).clear();
    ref.read(ofxAccountDetectionProvider.notifier).clear();
    ref.read(chosenImportAccountsProvider.notifier).clear();
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
                    onPickFile: _pickFile,
                    onDropFile: _stage,
                    onClearFile: _clearFile,
                    onImport: _import,
                    onCreateDetectedAccount: _createDetectedAccount,
                  ),
                ),
                if (lastResult != null) ...[
                  const SizedBox(width: AppSpacing.gridGap),
                  Expanded(flex: 100, child: _ResultCard(batches: lastResult)),
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
  // A card is named "Carte", not after its proposed type: the form asks how the
  // card is debited, and a name spelling out the answer would contradict a
  // user who picks the other one.
  final label = info.isCardStatement
      ? l10n.importCardAccountName
      : type == null
      ? info.institutionLabel
      : accountTypeLabel(l10n, type);
  return AccountPrefill(
    name: [?label, info.maskedNumber].join(' '),
    institution: info.institutionLabel,
    type: type,
    isCardStatement: info.isCardStatement,
    // Bound to the account so the next statement from it matches on identity
    // rather than on how the bank happens to spell its own name.
    ofxAccountId: info.accountNumber.trim(),
    // The statement's own closing balance, so the form asks the user to confirm
    // a figure rather than to remember one — dated, so the form can say which
    // day it belongs to instead of implying it is today's.
    balanceMinor: info.ledgerBalanceMinor,
    balanceAsOf: info.ledgerBalanceAsOf,
    // `CURDEF` — the currency the statement's own figures are in. Read from the
    // file rather than inherited from the profile: the balance just above comes
    // from this statement, and naming it in another currency would misstate it.
    currency: info.currency,
  );
}

/// How a detected account is named in the banners: `Boursorama ••4567`, or just
/// the masked number when the file names no bank.
String _detectedAccountLabel(OfxAccountInfo info) =>
    [?info.institutionLabel, info.maskedNumber].join(' ');

/// One statement of the staged file and the account it will be imported into.
typedef ImportTarget = ({String? statement, Account account});

/// Where each statement of the file lands: the account it resolved to, else the
/// one the user picked to settle a statement that couldn't resolve itself.
///
/// `null` means some statement isn't settled yet — or two would land in the
/// same account — and the panel must not import. Deliberately without a "first
/// account" fallback: the panel no longer carries a destination selector, so a
/// default here would file a statement against an account nobody chose and
/// nothing on screen would say so.
///
/// Pure so the rule is testable on its own, and shared by the staged-file row
/// and the import action so what is shown and what is imported into can't
/// diverge.
List<ImportTarget>? resolveImportTargets(
  List<OfxAccountMatch>? matches,
  Map<String?, String> chosen,
  List<Account> accounts,
) {
  final targets = _settledTargets(matches, chosen, accounts);
  return targets == null || hasSharedDestination(targets) ? null : targets;
}

/// Every statement's account, or `null` while any is still unanswered.
List<ImportTarget>? _settledTargets(
  List<OfxAccountMatch>? matches,
  Map<String?, String> chosen,
  List<Account> accounts,
) {
  if (matches == null || matches.isEmpty) return null;
  final targets = <ImportTarget>[];
  for (final match in matches) {
    final statement = statementKey(match);
    final account = match is OfxAccountMatched
        ? match.account
        : accounts.where((a) => a.id == chosen[statement]).firstOrNull;
    if (account == null) return null;
    targets.add((statement: statement, account: account));
  }
  return targets;
}

/// Whether two statements would land in the same account — always a mistake,
/// and the backend would silently keep only the first.
bool hasSharedDestination(List<ImportTarget> targets) =>
    targets.map((target) => target.account.id).toSet().length != targets.length;

/// Region A — the drop zone and what the staged statement says about itself.
class _NewImportCard extends ConsumerWidget {
  const _NewImportCard({
    required this.isImporting,
    required this.errorText,
    required this.onPickFile,
    required this.onDropFile,
    required this.onClearFile,
    required this.onImport,
    required this.onCreateDetectedAccount,
  });

  final bool isImporting;
  final String? errorText;
  final VoidCallback onPickFile;
  final ValueChanged<PickedImportFile> onDropFile;
  final VoidCallback onClearFile;
  final VoidCallback onImport;
  final ValueChanged<OfxAccountInfo> onCreateDetectedAccount;

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
          Text(
            l10n.importNewTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          // No destination field: the statement names its own account. All that
          // is left to say up here is when we couldn't even load the accounts to
          // match it against — without which detection stays silent.
          if (accounts is AsyncError) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: const Key('importAccountsErrorBanner'),
              message: l10n.importAccountsUnavailable,
            ),
          ],
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
              onClear: onClearFile,
              onImport: onImport,
            ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: const Key('importErrorBanner'),
              message: errorText!,
            ),
          ],
        ],
      ),
    );
  }
}

/// What each statement of the staged file says about its own account — and,
/// when the file can't answer that on its own, the controls that ask the user.
///
/// Renders nothing at all when there is nothing to say (no file staged).
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
    final matches = ref.watch(ofxAccountDetectionProvider);
    if (matches == null) return const SizedBox.shrink();
    final settled = _settledTargets(
      matches,
      ref.watch(chosenImportAccountsProvider),
      ref.watch(accountsControllerProvider).value ?? const <Account>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final match in matches)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _statementNotice(l10n, match),
          ),
        if (settled != null && hasSharedDestination(settled))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: InlineBanner(
              key: const Key('importSharedDestinationBanner'),
              message: l10n.importDuplicateDestination,
            ),
          ),
      ],
    );
  }

  Widget _statementNotice(
    AppLocalizations l10n,
    OfxAccountMatch match,
  ) => switch (match) {
    OfxAccountMatched(:final info, :final account) => InlineBanner(
      key: _statementWidgetKey('importDetectedAccountBanner', info),
      message: l10n.importDetectedAccount(account.name),
      tone: BannerTone.success,
    ),
    // The file names a bank the user has several accounts with. Only those
    // candidates are offered: the rest of the list is already ruled out by
    // the file, and showing it would invite filing the statement wrongly.
    OfxAccountAmbiguous(:final info, :final candidates) => _AccountChoice(
      statement: info.accountNumber,
      bannerKey: _statementWidgetKey('importAmbiguousAccountBanner', info),
      selectKey: _statementWidgetKey('importAmbiguousAccountField', info),
      message: l10n.importDetectedAccountAmbiguous(_detectedAccountLabel(info)),
      candidates: candidates,
      isImporting: isImporting,
    ),
    OfxAccountUnmatched(:final info) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        InlineBanner(
          key: _statementWidgetKey('importUnknownAccountBanner', info),
          message: l10n.importDetectedAccountUnknown(
            _detectedAccountLabel(info),
          ),
          tone: BannerTone.warning,
        ),
        TextButton(
          key: _statementWidgetKey('importCreateDetectedAccountButton', info),
          onPressed: isImporting ? null : () => onCreateAccount(info),
          child: Text(l10n.importCreateDetectedAccount),
        ),
      ],
    ),
    OfxAccountUnreadable() => _UnreadableAccountChoice(
      isImporting: isImporting,
    ),
  };
}

/// A per-statement widget key: [base] suffixed with the statement's `ACCTID`,
/// since a file covering several accounts shows one of each.
Key _statementWidgetKey(String base, OfxAccountInfo info) =>
    Key('$base-${info.accountNumber}');

/// The fallback for a file that declares no account at all: nothing can be
/// matched or proposed from it, so the user picks from every account they have.
///
/// Its own widget because it is the only case that needs the full account list,
/// which nothing in the verdict carries.
class _UnreadableAccountChoice extends ConsumerWidget {
  const _UnreadableAccountChoice({required this.isImporting});

  final bool isImporting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];

    return _AccountChoice(
      statement: null,
      bannerKey: const Key('importUnreadableAccountBanner'),
      selectKey: const Key('importUnreadableAccountField'),
      message: l10n.importUnreadableAccount,
      candidates: accounts,
      isImporting: isImporting,
    );
  }
}

/// A warning plus a picker over [candidates] — the panel's only manual account
/// choice, shown only when a statement could not name its own destination.
class _AccountChoice extends ConsumerWidget {
  const _AccountChoice({
    required this.statement,
    required this.bannerKey,
    required this.selectKey,
    required this.message,
    required this.candidates,
    required this.isImporting,
  });

  /// The statement this choice settles — its `ACCTID`, or `null` for a file
  /// that names no account.
  final String? statement;
  final Key bannerKey;
  final Key selectKey;
  final String message;
  final List<Account> candidates;
  final bool isImporting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chosenId = ref.watch(chosenImportAccountsProvider)[statement];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineBanner(
          key: bannerKey,
          message: message,
          tone: BannerTone.warning,
        ),
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          LabeledField(
            label: l10n.importAccountLabel,
            child: AppSelect<String?>(
              key: selectKey,
              value: chosenId,
              items: [
                // Carried as a real option so the field reads as an unanswered
                // question rather than as a blank well. Re-picking it simply
                // un-answers it, which disables the import again.
                AppSelectItem(value: null, label: l10n.importChooseAccount),
                for (final account in candidates)
                  AppSelectItem(
                    value: account.id,
                    label: account.name,
                    leading: InstitutionAvatar(
                      name: account.institution,
                      size: 24,
                    ),
                  ),
              ],
              onChanged: isImporting
                  ? (_) {}
                  : (selected) => ref
                        .read(chosenImportAccountsProvider.notifier)
                        .select(statement, selected),
            ),
          ),
        ],
      ],
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
    required this.onClear,
    required this.onImport,
  });

  final PickedImportFile file;
  final bool isImporting;
  final VoidCallback onClear;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final format = ImportFormat.fromWire(file.extension);
    // Watched, not read: the button turns live the moment detection lands or
    // the user answers the picker above.
    final targets = resolveImportTargets(
      ref.watch(ofxAccountDetectionProvider),
      ref.watch(chosenImportAccountsProvider),
      ref.watch(accountsControllerProvider).value ?? const <Account>[],
    );

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
                        l10n.importFileSize(
                          _formatKilobytes(file.bytes.length, locale),
                        ),
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
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PrimaryButton(
              key: const Key('importSubmitButton'),
              label: l10n.importSubmit,
              loadingLabel: l10n.importSubmitting,
              isLoading: isImporting,
              // Disabled until every statement has its own destination. The
              // notice above always says what is missing, so this never reads
              // as an unexplained dead button.
              onPressed: targets == null ? null : onImport,
            ),
          ],
        ),
      ],
    );
  }
}

String _formatKilobytes(int bytes, String locale) =>
    NumberFormat('#,##0.#', locale).format(bytes / 1024);

/// Region A' — what the import that just ran actually did: the counts summed
/// over every statement of the file, then each statement's own period,
/// destination and warnings.
class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.batches});

  final List<ImportBatch> batches;

  /// Failed only when nothing landed, success only when everything did.
  ImportStatus get _status {
    if (batches.every((b) => b.status == ImportStatus.failed)) {
      return ImportStatus.failed;
    }
    if (batches.every((b) => b.status == ImportStatus.success)) {
      return ImportStatus.success;
    }
    return ImportStatus.partial;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final status = _status;
    final newCount = batches.fold(0, (sum, b) => sum + b.newCount);
    final duplicateCount = batches.fold(0, (sum, b) => sum + b.duplicateCount);

    return AppCard(
      key: const Key('importResultCard'),
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.importResultTitle,
                  style: textTheme.titleMedium,
                ),
              ),
              ImportStatusPill(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (status == ImportStatus.failed)
            InlineBanner(
              key: const Key('importResultFailure'),
              message: l10n.importFailedNote,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _CountPlate(
                    valueKey: const Key('importResultNewCount'),
                    value: newCount,
                    label: l10n.importResultNewLabel(newCount),
                    color: AppColors.positive,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: _CountPlate(
                    valueKey: const Key('importResultDuplicateCount'),
                    value: duplicateCount,
                    label: l10n.importResultDuplicateLabel(duplicateCount),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          for (final batch in batches)
            _BatchOutcome(
              batch: batch,
              account: accounts
                  .where((account) => account.id == batch.accountId)
                  .firstOrNull,
            ),
        ],
      ),
    );
  }
}

/// One statement's line in the result card: its own warnings, the period it
/// covered and the account it went to.
class _BatchOutcome extends StatelessWidget {
  const _BatchOutcome({required this.batch, required this.account});

  final ImportBatch batch;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final accountName = account?.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (batch.status == ImportStatus.failed)
          if (batch.errorMessage case final message?
              when message.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTextStyles.mono),
          ],
        if (batch.balanceMismatchMinor case final mismatch?) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(
            key: Key('importResultBalanceMismatch-${batch.id}'),
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
          key: Key('importResultPeriod-${batch.id}'),
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
