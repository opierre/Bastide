import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../application/imports_controller.dart';
import '../domain/import_batch.dart';
import 'import_error_localizer.dart';

/// « Historique » (`docs/design/06-imports.md` §2): every import run, newest
/// first, in a table that takes the remaining height and scrolls inside it.
///
/// The history is the panel's audit trail: it is what tells the user a file was
/// already imported (and therefore why a re-import added nothing), and what a
/// failed file did *not* change.
class ImportHistory extends ConsumerWidget {
  const ImportHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final batches = ref.watch(importsControllerProvider);
    final columns = _columns(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: l10n.importHistoryTitle),
        Expanded(
          child: switch (batches) {
            AsyncData(:final value) when value.isEmpty => EmptyStateView(
              key: const Key('importHistoryEmpty'),
              title: l10n.importHistoryEmptyTitle,
              message: l10n.importHistoryEmptyBody,
            ),
            AsyncData(:final value) => _HistoryTable(
              columns: columns,
              batches: value,
            ),
            AsyncError(:final error) => ErrorStateView(
              message: localizeImportError(l10n, error),
              messageKey: const Key('importHistoryErrorText'),
              retryLabel: l10n.importRetry,
              retryKey: const Key('importHistoryRetryButton'),
              onRetry: () =>
                  ref.read(importsControllerProvider.notifier).refresh(),
            ),
            _ => _HistorySilhouette(columns: columns),
          },
        ),
      ],
    );
  }
}

/// The seven columns of the history, shared by the header, the rows and the
/// loading silhouette so they can't drift apart.
List<AppTableColumn> _columns(AppLocalizations l10n) => [
  AppTableColumn(label: l10n.importHistoryFileHeader, flex: 5),
  AppTableColumn(label: l10n.importHistoryAccountHeader, flex: 4),
  AppTableColumn(label: l10n.importHistoryImportedHeader, flex: 3),
  AppTableColumn(label: l10n.importHistoryPeriodHeader, flex: 4),
  AppTableColumn(label: l10n.importHistoryNewHeader, flex: 2, numeric: true),
  AppTableColumn(
    label: l10n.importHistoryDuplicatesHeader,
    flex: 2,
    numeric: true,
  ),
  AppTableColumn(label: l10n.importHistoryResultHeader, flex: 4, numeric: true),
];

class _HistoryTable extends ConsumerWidget {
  const _HistoryTable({required this.columns, required this.batches});

  final List<AppTableColumn> columns;
  final List<ImportBatch> batches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final highlighted = ref.watch(recentImportHighlightsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTableHeader(columns: columns),
        Expanded(
          child: ListView.builder(
            key: const Key('importHistoryList'),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              return _HistoryRow(
                columns: columns,
                batch: batch,
                account: accounts
                    .where((a) => a.id == batch.accountId)
                    .firstOrNull,
                highlighted: highlighted.contains(batch.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.columns,
    required this.batch,
    required this.account,
    required this.highlighted,
  });

  final List<AppTableColumn> columns;
  final ImportBatch batch;
  final Account? account;
  final bool highlighted;

  bool get _failed => batch.status == ImportStatus.failed;

  /// Opens Transactions on exactly the operations this import added. A
  /// failed import wrote nothing, so it opens nothing.
  void _open(BuildContext context, WidgetRef ref) {
    ref
        .read(transactionFiltersProvider.notifier)
        .showImport(
          ImportBatchFilter(id: batch.id, fileName: batch.fileName),
          accountId: batch.accountId,
        );
    context.go(TransactionsScreen.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final numberFormat = NumberFormat.decimalPattern(locale);
    final secondary = TextStyle(color: colors.textSecondary);
    final note = _note(l10n, colors, Theme.of(context).textTheme.bodySmall);
    final account = this.account;

    return AppTableRow(
      key: Key('importBatchRow-${batch.id}'),
      columns: columns,
      selected: highlighted,
      twoLines: note != null,
      onTap: _failed ? null : () => _open(context, ref),
      cells: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              batch.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            ?note,
          ],
        ),
        if (_failed || account == null)
          Text(l10n.importHistoryNoValue, style: secondary)
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonogramAvatar(name: account.institution),
              const SizedBox(width: AppSpacing.xsPlus),
              Flexible(child: Text(account.name)),
            ],
          ),
        Text(
          DateFormat.yMMMd(locale).format(batch.importedAt.toLocal()),
          style: secondary,
        ),
        Text(
          _failed
              ? l10n.importHistoryNoValue
              : l10n.importPeriodRange(
                  formatPeriodStart(batch.periodStart, batch.periodEnd, locale),
                  DateFormat.yMMMd(locale).format(batch.periodEnd),
                ),
          key: Key('importBatchPeriod-${batch.id}'),
          style: secondary,
        ),
        Text(numberFormat.format(batch.newCount)),
        Text(numberFormat.format(batch.duplicateCount), style: secondary),
        _Result(batch: batch, currency: account?.currency ?? ''),
      ],
    );
  }

  /// The 12 px second line under the file name, where a run explains itself:
  /// why a re-import added little, or that a failure changed nothing.
  Widget? _note(AppLocalizations l10n, AppColors colors, TextStyle? small) {
    if (_failed) {
      final note = Text(
        l10n.importFailedNote,
        key: Key('importBatchFailureNote-${batch.id}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: small?.copyWith(color: colors.negative),
      );
      // The parser's own words are the only thing that says *why* the file
      // was rejected; they stay a hover away rather than a third line.
      final reason = batch.errorMessage?.trim();
      if (reason == null || reason.isEmpty) return note;
      return Tooltip(message: reason, child: note);
    }
    if (batch.duplicateCount > 0) {
      return Text(
        l10n.importDuplicatesNote(batch.duplicateCount),
        key: Key('importBatchDuplicateNote-${batch.id}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: small?.copyWith(color: colors.warning),
      );
    }
    return null;
  }
}

/// The run's outcome as status text: « Réussi » neutral with `check`,
/// « Partiel » `warning`, « Échec » `negative`, led by « Écart de solde » in
/// `warning` when the statement disagrees with the ledger's balance.
class _Result extends StatelessWidget {
  const _Result({required this.batch, required this.currency});

  final ImportBatch batch;

  /// The account's currency, for the balance gap shown on hover.
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    final outcome = switch (batch.status) {
      ImportStatus.success => StatusText(
        label: l10n.importStatusSuccess,
        icon: LucideIcons300.check,
      ),
      ImportStatus.partial => StatusText(
        label: l10n.importStatusPartial,
        tone: StatusTone.warning,
      ),
      ImportStatus.failed => StatusText(
        label: l10n.importStatusFailed,
        tone: StatusTone.negative,
      ),
    };

    final mismatch = batch.balanceMismatchMinor;
    if (mismatch == null) return outcome;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Tooltip(
            message: l10n.importBalanceMismatchNote(
              formatAmount(
                amountMinor: mismatch,
                currency: currency,
                locale: locale,
                showPositiveSign: true,
              ),
              batch.balanceMismatchAsOf ?? batch.periodEnd,
            ),
            child: StatusText(
              key: Key('importBatchMismatch-${batch.id}'),
              label: l10n.importBalanceMismatchStatus,
              tone: StatusTone.warning,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.smPlus),
        Flexible(child: outcome),
      ],
    );
  }
}

/// The start of a period, shortened by what it shares with the end: « 1 » in
/// « 1 – 30 avr. 2026 », « 1 janv. » in « 1 janv. – 31 mars 2026 ».
String formatPeriodStart(DateTime start, DateTime end, String locale) {
  if (start.year != end.year) return DateFormat.yMMMd(locale).format(start);
  if (start.month != end.month) return DateFormat.MMMd(locale).format(start);
  return DateFormat.d(locale).format(start);
}

/// The table's silhouette while the history loads (`00` §7): the header, then
/// rows of `hover` blocks, pulsing together.
class _HistorySilhouette extends StatelessWidget {
  const _HistorySilhouette({required this.columns});

  final List<AppTableColumn> columns;

  static const _rows = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('importHistoryLoading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTableHeader(columns: columns),
        Expanded(
          child: SkeletonPulse(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < _rows; i++)
                  AppTableRow(
                    columns: columns,
                    cells: [
                      for (final _ in columns)
                        const SkeletonBlock(height: AppSpacing.smPlus),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
