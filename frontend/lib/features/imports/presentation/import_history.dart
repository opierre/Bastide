import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account.dart';
import '../application/imports_controller.dart';
import '../domain/import_batch.dart';
import 'import_error_localizer.dart';

/// Region C — every import run, most recent first.
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
    // Needed only to format a mismatch amount in the account's own currency;
    // the account list is already loaded for the panel's selector, so this is
    // never a first fetch of its own.
    final accounts = ref.watch(accountsControllerProvider).value ?? const <Account>[];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.importHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: switch (batches) {
              AsyncData(:final value) when value.isEmpty => EmptyStateView(
                key: const Key('importHistoryEmpty'),
                icon: Icons.download_outlined,
                title: l10n.importHistoryEmptyTitle,
                message: l10n.importHistoryEmptyBody,
              ),
              AsyncData(:final value) => _HistoryTable(batches: value, accounts: accounts),
              AsyncError(:final error) => ErrorStateView(
                message: localizeImportError(l10n, error),
                messageKey: const Key('importHistoryErrorText'),
                retryLabel: l10n.importRetry,
                retryKey: const Key('importHistoryRetryButton'),
                onRetry: () => ref.read(importsControllerProvider.notifier).refresh(),
              ),
              _ => const SkeletonList(
                key: Key('importHistoryLoading'),
                itemCount: 4,
                itemHeight: 46,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.batches, required this.accounts});

  final List<ImportBatch> batches;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(l10n: l10n),
        Expanded(
          child: ListView.separated(
            key: const Key('importHistoryList'),
            itemCount: batches.length,
            separatorBuilder: (_, _) => const Divider(color: AppColors.borderSubtle),
            itemBuilder: (context, index) => _HistoryRow(
              batch: batches[index],
              currency: _currencyFor(accounts, batches[index].accountId),
            ),
          ),
        ),
      ],
    );
  }
}

/// The currency of the account a batch belongs to, when that account is
/// still loaded — falling back to an empty string, which `NumberFormat`
/// resolves from the ambient locale rather than throwing.
String _currencyFor(List<Account> accounts, String accountId) {
  for (final account in accounts) {
    if (account.id == accountId) return account.currency;
  }
  return '';
}

/// Column proportions shared by the header and every row, so the two can't
/// drift, plus the gutter between two columns.
///
/// Shares rather than pixel widths: the panel is as wide as the window, and
/// pinning six columns to fixed widths spent every extra pixel on the file
/// name while a date range or a status pill stayed clipped at the width it was
/// born with. Proportions let each column grow with the table.
const _fileFlex = 30;
const _formatFlex = 10;
const _importedFlex = 14;
const _periodFlex = 20;
const _countFlex = 10;
const _statusFlex = 14;
const _columnGap = AppSpacing.sm + AppSpacing.xs;

/// Lays seven cells out on the shared column grid. Both the header and every
/// row build through this, so a column can't be widened in one and not the
/// other.
Widget _columnRow({
  required Widget file,
  required Widget format,
  required Widget imported,
  required Widget period,
  required Widget newCount,
  required Widget duplicates,
  required Widget status,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
}) {
  return Row(
    crossAxisAlignment: crossAxisAlignment,
    children: [
      Expanded(flex: _fileFlex, child: file),
      const SizedBox(width: _columnGap),
      Expanded(flex: _formatFlex, child: format),
      const SizedBox(width: _columnGap),
      Expanded(flex: _importedFlex, child: imported),
      const SizedBox(width: _columnGap),
      Expanded(flex: _periodFlex, child: period),
      const SizedBox(width: _columnGap),
      Expanded(flex: _countFlex, child: newCount),
      const SizedBox(width: _columnGap),
      Expanded(flex: _countFlex, child: duplicates),
      const SizedBox(width: _columnGap),
      Expanded(flex: _statusFlex, child: status),
    ],
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, {TextAlign align = TextAlign.center}) => Text(
      label.toUpperCase(),
      textAlign: align,
      style: AppTextStyles.sectionLabel,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _columnRow(
        crossAxisAlignment: CrossAxisAlignment.end,
        // The file column is the only one that stays left: it carries a wrapped name and
        // up to three explanatory notes under it, and a centred block of ragged text reads
        // as misaligned rather than as a value under its header.
        file: cell(l10n.importHistoryFileHeader, align: TextAlign.left),
        format: cell(l10n.importHistoryFormatHeader),
        imported: cell(l10n.importHistoryImportedHeader),
        period: cell(l10n.importHistoryPeriodHeader),
        newCount: cell(l10n.importHistoryNewHeader),
        duplicates: cell(l10n.importHistoryDuplicatesHeader),
        status: cell(l10n.importHistoryStatusHeader),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.batch, required this.currency});

  final ImportBatch batch;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat.yMd(locale);
    final numberFormat = NumberFormat.decimalPattern(locale);

    return Padding(
      key: Key('importBatchRow-${batch.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: _columnRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        file: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              batch.fileName,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
            // The note under the filename is where a run explains itself:
            // why a re-import added nothing, or what a failure left alone.
            if (batch.status == ImportStatus.failed) ...[
              const SizedBox(height: 2),
              Text(
                l10n.importFailedNote,
                key: Key('importBatchFailureNote-${batch.id}'),
                style: AppTextStyles.helper.copyWith(color: AppColors.negative),
              ),
              if (batch.errorMessage case final message?
                  when message.trim().isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  message,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mono.copyWith(color: AppColors.textDisabled),
                ),
              ],
            ] else if (batch.duplicateCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                l10n.importDuplicatesNote(batch.duplicateCount),
                key: Key('importBatchDuplicateNote-${batch.id}'),
                style: AppTextStyles.helper.copyWith(color: AppColors.warning),
              ),
            ],
            // Independent of the notes above: a statement can both skip
            // duplicates and disagree with the ledger's balance.
            if (batch.balanceMismatchMinor case final mismatch?) ...[
              const SizedBox(height: 2),
              Text(
                l10n.importBalanceMismatchNote(
                  formatAmount(
                    amountMinor: mismatch,
                    currency: currency,
                    locale: locale,
                    showPositiveSign: true,
                  ),
                  batch.balanceMismatchAsOf!,
                ),
                key: Key('importBatchMismatchNote-${batch.id}'),
                style: AppTextStyles.helper.copyWith(color: AppColors.warning),
              ),
            ],
          ],
        ),
        // Every value column is centred so it sits under its own header rather than beside
        // it — the chips included, which is why both pills take an alignment.
        format: ImportFormatBadge(
          format: batch.sourceFormat,
          alignment: Alignment.topCenter,
        ),
        imported: Text(
          dateFormat.format(batch.importedAt.toLocal()),
          textAlign: TextAlign.center,
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: AppColors.textSecondary),
        ),
        period: Text(
          l10n.importPeriodRange(batch.periodStart, batch.periodEnd),
          textAlign: TextAlign.center,
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: AppColors.textSecondary),
        ),
        newCount: Text(
          numberFormat.format(batch.newCount),
          textAlign: TextAlign.center,
          style: tabularNumberStyle(textTheme.bodyMedium!),
        ),
        duplicates: Text(
          numberFormat.format(batch.duplicateCount),
          textAlign: TextAlign.center,
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: AppColors.textSecondary),
        ),
        status: ImportStatusPill(
          status: batch.status,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}

/// Source-format badge. The hue per format is pinned by
/// `docs/design/06-imports.md`: OFX blue, QFX violet.
class ImportFormatBadge extends StatelessWidget {
  const ImportFormatBadge({
    super.key,
    required this.format,
    this.alignment = Alignment.centerLeft,
  });

  final ImportFormat format;

  /// Where the pill sits in the space it is given — the history table centres it under its
  /// column header; elsewhere it hugs the leading edge.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final color = switch (format) {
      ImportFormat.ofx => AppColors.info,
      ImportFormat.qfx => AppColors.iris,
    };

    return Align(
      alignment: alignment,
      child: AppChip(label: format.name.toUpperCase(), color: color),
    );
  }
}

/// Outcome pill. The glyph doubles the hue so the status never rests on color
/// alone (see the shared design block's accessibility rule).
class ImportStatusPill extends StatelessWidget {
  const ImportStatusPill({
    super.key,
    required this.status,
    this.alignment = Alignment.centerLeft,
  });

  final ImportStatus status;

  /// See [ImportFormatBadge.alignment].
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (color, icon, label) = switch (status) {
      ImportStatus.success => (
        AppColors.positive,
        Icons.check_rounded,
        l10n.importStatusSuccess,
      ),
      ImportStatus.partial => (
        AppColors.warning,
        Icons.warning_amber_rounded,
        l10n.importStatusPartial,
      ),
      ImportStatus.failed => (
        AppColors.negative,
        Icons.close_rounded,
        l10n.importStatusFailed,
      ),
    };

    return Align(
      alignment: alignment,
      child: AppChip(label: label, color: color, icon: icon),
    );
  }
}
