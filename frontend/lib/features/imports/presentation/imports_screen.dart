import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_form.dart';
import '../../accounts/presentation/account_type_label.dart';
import '../../accounts/presentation/card_settlement_warnings.dart';
import '../application/import_targets.dart';
import '../application/imports_controller.dart';
import '../application/ofx_account_detection.dart';
import '../domain/import_batch.dart';
import '../domain/ofx_account_info.dart';
import 'import_error_localizer.dart';
import 'import_history.dart';

/// The imports panel (`docs/design/06-imports.md`): a compact drop target,
/// one line per statement of the selected file, then the history.
///
/// There is no destination field. An OFX file carries its own account block,
/// so the panel reads the destination out of the file and only asks when the
/// file leaves the question genuinely open — see [OfxAccountMatch].
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
  /// The statements being imported right now, by `ACCTID` (`null` for a file
  /// that names no account). Their lines show the spinner and can't be removed.
  final Set<String?> _importing = {};

  /// Whether the run in flight is « Importer tout », whose button then spins.
  bool _importingAll = false;
  String? _errorText;

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
    ref.read(selectedImportFileProvider.notifier).clear();
    ref.read(ofxAccountDetectionProvider.notifier).clear();
    ref.read(chosenImportAccountsProvider.notifier).clear();
  }

  /// Drops one statement line; the file goes with its last line.
  void _removeStatement(String? statement) {
    setState(() => _errorText = null);
    ref.read(ofxAccountDetectionProvider.notifier).remove(statement);
    ref.read(chosenImportAccountsProvider.notifier).select(statement, null);
    if (ref.read(ofxAccountDetectionProvider)?.isEmpty ?? true) _clearFile();
  }

  /// Points each statement at the account it names.
  ///
  /// An OFX file carries its own account blocks, so the panel reads the
  /// destinations out of the file rather than asking for them. A statement no
  /// account matches describes an account the user hasn't created yet, so we
  /// offer to create each in turn from what the file says; when the file can't
  /// settle one alone, its line asks.
  Future<void> _detectAccount(PickedImportFile file) async {
    final List<Account> accounts;
    try {
      accounts = await ref.read(accountsControllerProvider.future);
    } catch (_) {
      // The panel already reports that the account list failed to load;
      // detection just stays silent rather than adding a second error.
      ref.read(ofxAccountDetectionProvider.notifier).clear();
      return;
    }
    // The staged file may have been replaced or cleared while we waited.
    if (!mounted || ref.read(selectedImportFileProvider) != file) return;

    final matches = await ref
        .read(ofxAccountDetectionProvider.notifier)
        .detect(file, accounts);

    // Matched needs nothing — the verdict *is* the destination. The other
    // unresolved cases are put to the user by their line rather than here.
    for (final match in matches) {
      if (!mounted || ref.read(selectedImportFileProvider) != file) return;
      if (match case OfxAccountUnmatched(:final info)) {
        await _createDetectedAccount(info);
      }
    }
  }

  /// Opens the account form pre-filled from the statement, and imports into the
  /// account it creates. Cancelling leaves the line and its button in place,
  /// so the offer can be taken up later.
  Future<void> _createDetectedAccount(OfxAccountInfo info) async {
    final l10n = AppLocalizations.of(context)!;
    final created = await showAccountForm(
      context,
      // Its rule is offered with the import's result, once the card's history
      // is in: that is what the rule's start date is read from.
      offerSettlementRule: false,
      prefill: _prefillFrom(
        info,
        l10n,
        settlementAccountId: info.isCardStatement
            ? settlingAccountFor(
                info,
                ref.read(ofxAccountDetectionProvider) ?? const [],
              )?.id
            : null,
      ),
    );
    if (created == null || !mounted) return;
    ref.read(ofxAccountDetectionProvider.notifier).resolveTo(info, created);
  }

  /// Uploads one statement of the staged file into the account it resolved to.
  ///
  /// The line leaves once its batch is back, and the batch tops the history.
  /// A `failed` batch is a normal return: the backend records it in the history
  /// and nothing was written. A request that throws leaves the line staged —
  /// retrying is safe, since a statement already imported into its account
  /// comes back as its original batch.
  Future<void> _import(OfxAccountMatch match) async {
    final file = ref.read(selectedImportFileProvider);
    final matches = ref.read(ofxAccountDetectionProvider) ?? const [];
    final target = importTargetFor(
      match,
      matches,
      ref.read(chosenImportAccountsProvider),
      ref.read(accountsControllerProvider).value ?? const <Account>[],
    );
    if (target == null || file == null) return;
    await _importTargets(file, [target]);
  }

  /// « Importer tout »: every statement that can import right now, one after
  /// the other. Statements still waiting on an answer keep their line.
  Future<void> _importAll() async {
    final file = ref.read(selectedImportFileProvider);
    final targets = readyImportTargets(
      ref.read(ofxAccountDetectionProvider) ?? const [],
      ref.read(chosenImportAccountsProvider),
      ref.read(accountsControllerProvider).value ?? const <Account>[],
    );
    if (targets.isEmpty || file == null) return;
    setState(() => _importingAll = true);
    try {
      await _importTargets(file, targets);
    } finally {
      if (mounted) setState(() => _importingAll = false);
    }
  }

  /// Uploads [targets] in turn and confirms them with a single toast.
  ///
  /// Sequential rather than parallel: each import moves balances and history
  /// the next one reads, and the sidecar takes one write at a time anyway.
  /// Every line shows its spinner from the start, so none can be removed or
  /// re-pointed mid-run. A statement that throws keeps its line and the run
  /// moves on: the others don't depend on it, and retrying is safe.
  Future<void> _importTargets(
    PickedImportFile file,
    List<ImportTarget> targets,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.maybeOf(context);
    setState(() {
      _importing.addAll(targets.map((t) => t.statement));
      _errorText = null;
    });
    final batches = <ImportBatch>[];
    for (final target in targets) {
      try {
        final batch = await ref
            .read(importsControllerProvider.notifier)
            .importFile(
              accountId: target.account.id,
              file: file,
              statement: target.statement,
            );
        if (!mounted) return;
        batches.add(batch);
        ref.read(lastImportResultProvider.notifier).add(batch);
        ref.read(recentImportHighlightsProvider.notifier).mark(batch.id);
        if (ref.read(selectedImportFileProvider) == file) {
          _removeStatement(target.statement);
        }
      } catch (error) {
        if (!mounted) return;
        setState(() => _errorText = localizeImportError(l10n, error));
      } finally {
        if (mounted) setState(() => _importing.remove(target.statement));
      }
    }
    if (overlay != null && batches.isNotEmpty) {
      _confirm(overlay, l10n, batches);
    }
  }

  /// The toast that confirms what the imports did: their summed counts, or
  /// that the files the backend rejected changed nothing.
  void _confirm(
    OverlayState overlay,
    AppLocalizations l10n,
    List<ImportBatch> batches,
  ) {
    final written = batches.where((b) => b.status != ImportStatus.failed);
    if (written.isEmpty) {
      showAppToastOn(
        overlay,
        title: l10n.importFailedNote,
        tone: BannerTone.error,
      );
      return;
    }
    showAppToastOn(
      overlay,
      title: l10n.importToastSummary(
        written.fold(0, (sum, b) => sum + b.newCount),
        written.fold(0, (sum, b) => sum + b.duplicateCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsControllerProvider);
    final hasImported = ref.watch(lastImportResultProvider) != null;

    return Padding(
      key: const Key('screen-imports'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DropTarget(onPickFile: _pickFile, onDropFile: _stage),
          // Without the account list there is nothing to match a statement
          // against, so detection stays silent; this says why.
          if (accounts is AsyncError) ...[
            const SizedBox(height: _lineGap),
            InlineBanner(
              key: const Key('importAccountsErrorBanner'),
              message: l10n.importAccountsUnavailable,
            ),
          ],
          _StatementLines(
            importing: _importing,
            importingAll: _importingAll,
            onRemove: _removeStatement,
            onImport: _import,
            onImportAll: _importAll,
            onCreateAccount: _createDetectedAccount,
          ),
          if (_errorText case final error?) ...[
            const SizedBox(height: _lineGap),
            InlineBanner(key: const Key('importErrorBanner'), message: error),
          ],
          // A card's settlement depends on the history just imported, so its
          // warnings qualify an import's result and wait for one.
          if (hasImported) const CardSettlementWarnings(),
          const SizedBox(height: AppSpacing.section),
          const Expanded(child: ImportHistory()),
        ],
      ),
    );
  }
}

/// The space between the drop target and the selected-file lines, and between
/// two lines (`06-imports.md`: 10 px).
const _lineGap = AppSpacing.sm + AppSpacing.xxs;

/// The statement's account phrased for the account form: a name built from the
/// type and the last digits of the account number, plus the bank's own name for
/// itself. Everything stays editable — the user renames it if they prefer.
AccountPrefill _prefillFrom(
  OfxAccountInfo info,
  AppLocalizations l10n, {
  String? settlementAccountId,
}) {
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
    settlementAccountId: settlementAccountId,
  );
}

/// How a detected account is named on its line: `Boursorama ••4567`, or just
/// the masked number when the file names no bank.
String _detectedAccountLabel(OfxAccountInfo info) =>
    [?info.institutionLabel, info.maskedNumber].join(' ');

/// A per-statement widget key: [base] suffixed with the statement's `ACCTID`,
/// since a file covering several accounts shows one line each. A file naming
/// no account has a single line, keyed by [base] alone.
Key _lineKey(String base, String? statement) =>
    statement == null ? Key(base) : Key('$base-$statement');

/// The drop target of `00` §7: 1 px dashed `lineStrong`, radius 8, padding
/// 18 20; the `file-up` icon, one line of text, one line of help and a
/// secondary « Parcourir ». Clicking anywhere opens the file dialog; dragging
/// a file over it turns the border `accent` on an `accentSoft` ground.
class _DropTarget extends StatefulWidget {
  const _DropTarget({required this.onPickFile, required this.onDropFile});

  final VoidCallback onPickFile;
  final ValueChanged<PickedImportFile> onDropFile;

  @override
  State<_DropTarget> createState() => _DropTargetState();
}

class _DropTargetState extends State<_DropTarget> {
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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('importDropZone'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPickFile,
          child: DashedBorder(
            key: const Key('importDropZoneBorder'),
            color: _dragging ? colors.accent : colors.lineStrong,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.dropTargetX,
                vertical: AppSpacing.dropTargetY,
              ),
              decoration: BoxDecoration(
                color: _dragging ? colors.accentSoft : null,
                borderRadius: BorderRadius.circular(AppRadii.container),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons300.fileUp,
                    size: AppSizes.icon,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.smPlus),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.importDropZoneTitle,
                          style: textTheme.bodyMedium,
                        ),
                        Text(
                          l10n.importDropZoneHint,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smPlus),
                  AppButton(
                    key: const Key('importBrowseButton'),
                    label: l10n.importBrowse,
                    onPressed: widget.onPickFile,
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

/// One line per statement of the selected file, 10 px under the drop target.
/// Renders nothing while no file is selected.
class _StatementLines extends ConsumerWidget {
  const _StatementLines({
    required this.importing,
    required this.importingAll,
    required this.onRemove,
    required this.onImport,
    required this.onImportAll,
    required this.onCreateAccount,
  });

  final Set<String?> importing;
  final bool importingAll;
  final ValueChanged<String?> onRemove;
  final ValueChanged<OfxAccountMatch> onImport;
  final VoidCallback onImportAll;
  final ValueChanged<OfxAccountInfo> onCreateAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final file = ref.watch(selectedImportFileProvider);
    final matches = ref.watch(ofxAccountDetectionProvider);
    if (file == null || matches == null) return const SizedBox.shrink();
    final chosen = ref.watch(chosenImportAccountsProvider);
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final shared = statementsSharingDestination(matches, chosen, accounts);
    // « Importer tout » only means something when the file holds several
    // statements. It then takes the view's one primary, and each line's own
    // « Importer » steps down to secondary (`00` §6: one primary per view).
    final multiple = matches.length > 1;
    final ready = readyImportTargets(matches, chosen, accounts);
    // Disabled while any statement is in flight, so a line being imported
    // on its own is never sent a second time.
    final importingAny = importing.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final match in matches)
          Padding(
            padding: const EdgeInsets.only(top: _lineGap),
            child: _StatementLine(
              file: file,
              match: match,
              accounts: accounts,
              sharesDestination: shared.contains(statementKey(match)),
              // Watched, not read: the button turns live the moment detection
              // lands or the user answers the line's select.
              canImport:
                  importTargetFor(match, matches, chosen, accounts) != null,
              isImporting: importing.contains(statementKey(match)),
              isPrimary: !multiple,
              onRemove: () => onRemove(statementKey(match)),
              onImport: () => onImport(match),
              onCreateAccount: onCreateAccount,
            ),
          ),
        if (multiple)
          Padding(
            padding: const EdgeInsets.only(top: _lineGap),
            child: Align(
              alignment: Alignment.centerRight,
              child: PrimaryButton(
                key: const Key('importAllButton'),
                label: l10n.importAll,
                loadingLabel: l10n.importSubmitting,
                isLoading: importingAll,
                // Live while at least one statement can go. Lines still
                // waiting on an answer say so themselves and stay behind.
                onPressed: ready.isEmpty || importingAny ? null : onImportAll,
              ),
            ),
          ),
      ],
    );
  }
}

/// A selected-file line (`06-imports.md`), a banner: `file-text` · file name
/// in Geist Mono · size · hairline · the detection result · ghost « Retirer »
/// · primary « Importer ».
class _StatementLine extends StatelessWidget {
  const _StatementLine({
    required this.file,
    required this.match,
    required this.accounts,
    required this.sharesDestination,
    required this.canImport,
    required this.isImporting,
    required this.isPrimary,
    required this.onRemove,
    required this.onImport,
    required this.onCreateAccount,
  });

  final PickedImportFile file;
  final OfxAccountMatch match;
  final List<Account> accounts;
  final bool sharesDestination;
  final bool canImport;
  final bool isImporting;

  /// Whether the line's « Importer » is the view's primary: only when the
  /// file holds a single statement, since « Importer tout » takes it otherwise.
  final bool isPrimary;
  final VoidCallback onRemove;
  final VoidCallback onImport;
  final ValueChanged<OfxAccountInfo> onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final statement = statementKey(match);
    final unreadable = match is OfxFileUnreadable;

    return InlineBanner.custom(
      key: _lineKey('importStatementLine', statement),
      icon: LucideIcons300.fileText,
      content: Row(
        children: [
          Flexible(
            child: Text(
              file.name,
              key: _lineKey('importStagedFileName', statement),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(fontFamily: AppFonts.mono),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.importFileSize(_formatKilobytes(file.bytes.length, locale)),
            style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(width: 1, height: AppSpacing.md, color: colors.line),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: _Detection(
              match: match,
              accounts: accounts,
              sharesDestination: sharesDestination,
              isImporting: isImporting,
              onCreateAccount: onCreateAccount,
            ),
          ),
        ],
      ),
      actions: [
        AppButton(
          key: _lineKey('importRemoveFileButton', statement),
          label: l10n.importRemoveFile,
          icon: LucideIcons300.x,
          variant: AppButtonVariant.ghost,
          onPressed: isImporting ? null : onRemove,
        ),
        // An unreadable file has nothing to import: only « Retirer ».
        if (!unreadable)
          AppButton(
            key: _lineKey('importSubmitButton', statement),
            label: l10n.importSubmit,
            loadingLabel: l10n.importSubmitting,
            variant: isPrimary
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            isLoading: isImporting,
            // Disabled until the statement has its own destination. The
            // detection result always says what is missing, so this never
            // reads as an unexplained dead button.
            onPressed: canImport ? onImport : null,
          ),
      ],
    );
  }
}

/// What the line says about the statement's account, and the control that
/// settles it when the file can't.
class _Detection extends ConsumerWidget {
  const _Detection({
    required this.match,
    required this.accounts,
    required this.sharesDestination,
    required this.isImporting,
    required this.onCreateAccount,
  });

  final OfxAccountMatch match;
  final List<Account> accounts;
  final bool sharesDestination;
  final bool isImporting;
  final ValueChanged<OfxAccountInfo> onCreateAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statement = statementKey(match);

    final (status, control) = switch (match) {
      OfxAccountMatched(:final account) => (
        StatusText(
          key: _lineKey('importDetectedAccountBanner', statement),
          label: l10n.importDetectionRecognised,
          tone: StatusTone.positive,
        ),
        _AccountName(account: account),
      ),
      // The file names a bank the user has several accounts with. Only those
      // candidates are offered: the rest of the list is already ruled out by
      // the file, and showing it would invite filing the statement wrongly.
      OfxAccountAmbiguous(:final info, :final candidates) => (
        Tooltip(
          message: l10n.importDetectedAccountAmbiguous(
            _detectedAccountLabel(info),
          ),
          child: StatusText(
            key: _lineKey('importAmbiguousAccountBanner', statement),
            label: l10n.importDetectionAmbiguous,
            tone: StatusTone.warning,
          ),
        ),
        _AccountChoice(
          key: _lineKey('importAmbiguousAccountField', statement),
          statement: statement,
          candidates: candidates,
          isImporting: isImporting,
        ),
      ),
      OfxAccountUnmatched(:final info) => (
        StatusText(
          key: _lineKey('importUnknownAccountBanner', statement),
          label: l10n.importDetectedAccountUnknown(_detectedAccountLabel(info)),
          tone: StatusTone.warning,
        ),
        AppButton(
          key: _lineKey('importCreateDetectedAccountButton', statement),
          label: l10n.importCreateDetectedAccount,
          onPressed: isImporting ? null : () => onCreateAccount(info),
        ),
      ),
      // Nothing can be matched or proposed from a file that names no account,
      // so this is the one case where the user picks from every account.
      OfxAccountUnreadable() => (
        Tooltip(
          message: l10n.importUnreadableAccount,
          child: StatusText(
            key: const Key('importUnreadableAccountBanner'),
            label: l10n.importDetectionNoAccount,
            tone: StatusTone.warning,
          ),
        ),
        accounts.isEmpty
            ? null
            : _AccountChoice(
                key: const Key('importUnreadableAccountField'),
                statement: null,
                candidates: accounts,
                isImporting: isImporting,
              ),
      ),
      OfxFileUnreadable(:final unsupportedFormat) => (
        StatusText(
          key: const Key('importUnreadableFileBanner'),
          label: unsupportedFormat
              ? l10n.importUnsupportedFormat
              : l10n.importFailedNote,
          tone: StatusTone.negative,
        ),
        null,
      ),
    };

    // Two statements pointed at one account: the collision is what the user
    // has to fix, so it replaces the detection message. The select stays, so
    // the line can still be pointed elsewhere.
    final shown = sharesDestination
        ? StatusText(
            key: _lineKey('importSharedDestinationBanner', statement),
            label: l10n.importDuplicateDestination,
            tone: StatusTone.negative,
          )
        : status;
    final keepsControl = !sharesDestination || control is _AccountChoice;

    return Row(
      children: [
        Flexible(child: shown),
        if (keepsControl && control != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: control),
        ],
      ],
    );
  }
}

/// The account a statement resolved to: its monogram and name.
class _AccountName extends StatelessWidget {
  const _AccountName({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonogramAvatar(name: account.institution),
        const SizedBox(width: AppSpacing.xsPlus),
        Flexible(
          child: Text(
            account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// A 28 px select over [candidates] — the panel's only manual account choice,
/// shown only when a statement could not name its own destination.
class _AccountChoice extends ConsumerWidget {
  const _AccountChoice({
    super.key,
    required this.statement,
    required this.candidates,
    required this.isImporting,
  });

  /// The statement this choice settles — its `ACCTID`, or `null` for a file
  /// that names no account.
  final String? statement;
  final List<Account> candidates;
  final bool isImporting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chosenId = ref.watch(chosenImportAccountsProvider)[statement];

    return ConstrainedBox(
      // As wide as a toolbar field: the line is a toolbar of its own.
      constraints: const BoxConstraints(maxWidth: AppSizes.searchField),
      child: AppSelect<String?>.toolbar(
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
              leading: MonogramAvatar(name: account.institution),
            ),
        ],
        onChanged: isImporting
            ? null
            : (selected) => ref
                  .read(chosenImportAccountsProvider.notifier)
                  .select(statement, selected),
      ),
    );
  }
}

String _formatKilobytes(int bytes, String locale) =>
    NumberFormat('#,##0.#', locale).format(bytes / 1024);
