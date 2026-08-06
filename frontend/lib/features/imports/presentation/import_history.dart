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

/// Column widths shared by the header and every row, so the two can't drift.
const _formatWidth = 84.0;
const _importedWidth = 118.0;
const _periodWidth = 168.0;
const _countWidth = 82.0;
const _statusWidth = 116.0;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, {double? width, TextAlign align = TextAlign.left}) {
      final text = Text(
        label.toUpperCase(),
        textAlign: align,
        style: AppTextStyles.sectionLabel,
      );
      return width == null ? Expanded(child: text) : SizedBox(width: width, child: text);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          cell(l10n.importHistoryFileHeader),
          cell(l10n.importHistoryFormatHeader, width: _formatWidth),
          cell(l10n.importHistoryImportedHeader, width: _importedWidth),
          cell(l10n.importHistoryPeriodHeader, width: _periodWidth),
          cell(l10n.importHistoryNewHeader, width: _countWidth, align: TextAlign.right),
          cell(
            l10n.importHistoryDuplicatesHeader,
            width: _countWidth,
            align: TextAlign.right,
          ),
          cell(l10n.importHistoryStatusHeader, width: _statusWidth),
        ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
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
          ),
          SizedBox(width: _formatWidth, child: ImportFormatBadge(format: batch.sourceFormat)),
          SizedBox(
            width: _importedWidth,
            child: Text(
              dateFormat.format(batch.importedAt.toLocal()),
              style: tabularNumberStyle(
                textTheme.bodyMedium!,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: _periodWidth,
            child: Text(
              l10n.importPeriodRange(batch.periodStart, batch.periodEnd),
              style: tabularNumberStyle(
                textTheme.bodyMedium!,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: _countWidth,
            child: Text(
              numberFormat.format(batch.newCount),
              textAlign: TextAlign.right,
              style: tabularNumberStyle(textTheme.bodyMedium!),
            ),
          ),
          SizedBox(
            width: _countWidth,
            child: Text(
              numberFormat.format(batch.duplicateCount),
              textAlign: TextAlign.right,
              style: tabularNumberStyle(
                textTheme.bodyMedium!,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(width: _statusWidth, child: ImportStatusPill(status: batch.status)),
        ],
      ),
    );
  }
}

/// Source-format badge. The hue per format is pinned by
/// `docs/design/06-imports.md`: OFX blue, QFX violet, CSV amber.
class ImportFormatBadge extends StatelessWidget {
  const ImportFormatBadge({super.key, required this.format});

  final ImportFormat format;

  @override
  Widget build(BuildContext context) {
    final color = switch (format) {
      ImportFormat.ofx => AppColors.info,
      ImportFormat.qfx => AppColors.iris,
      ImportFormat.csv => AppColors.warning,
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: AppChip(label: format.name.toUpperCase(), color: color),
    );
  }
}

/// Outcome pill. The glyph doubles the hue so the status never rests on color
/// alone (see the shared design block's accessibility rule).
class ImportStatusPill extends StatelessWidget {
  const ImportStatusPill({super.key, required this.status});

  final ImportStatus status;

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
      alignment: Alignment.centerLeft,
      child: AppChip(label: label, color: color, icon: icon),
    );
  }
}
