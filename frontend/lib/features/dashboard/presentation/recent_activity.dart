import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_trends.dart';

/// « Activité récente » — the compact TransactionRow variant: a 28px monogram, the merchant
/// over its account, and the amount over its date. No CategoryChip: this list is a glance at
/// what moved, and the panel that categorises is one link away (`docs/design/04-dashboard.md`
/// §Row 3).
class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    super.key,
    required this.transactions,
    required this.onViewAll,
  });

  final List<RecentTransaction> transactions;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dashboardRecentActivityTitle,
                  style: textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // The link rides the title rather than the card's bottom edge: the list below
              // it is sized to fill, so a trailing link would be pinned under a variable
              // number of rows instead of sitting on a fixed line the eye can find.
              TextButton(
                key: const Key('dashboardViewAllTransactions'),
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.iris,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.dashboardViewAllTransactions),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      l10n.dashboardRecentActivityEmpty,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    // The card is as tall as row 2 beside it, so the list is drawn to fill
                    // rather than to a fixed count: as many of the loaded transactions as
                    // fit at the spec's 48px row, sharing the leftover so the last row lands
                    // on the card's bottom edge. The rows are allowed to grow a quarter over
                    // spec — past that a short list would read as a spaced-out menu, so the
                    // remainder is left as air instead.
                    builder: (context, constraints) {
                      const rowHeight = CompactTransactionRow.rowHeight;
                      if (!constraints.hasBoundedHeight) {
                        return _RowList(
                          transactions: transactions,
                          height: rowHeight,
                        );
                      }

                      final fits = (constraints.maxHeight ~/ rowHeight).clamp(
                        1,
                        transactions.length,
                      );
                      return _RowList(
                        transactions: transactions.take(fits).toList(),
                        height: math.min(
                          rowHeight * 1.25,
                          constraints.maxHeight / fits,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RowList extends StatelessWidget {
  const _RowList({required this.transactions, required this.height});

  final List<RecentTransaction> transactions;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final transaction in transactions)
          CompactTransactionRow(transaction: transaction, height: height),
      ],
    );
  }
}

/// The 48px compact row. Sibling of the transactions panel's 52px [TransactionRow], which
/// carries a category chip and a wider monogram — see `docs/design/00` §Components.
class CompactTransactionRow extends StatelessWidget {
  const CompactTransactionRow({
    super.key,
    required this.transaction,
    this.height = rowHeight,
  });

  final RecentTransaction transaction;

  /// The row's height. Defaults to the spec's 48; the list tightens it when the card it sits
  /// in is shorter than four full rows.
  final double height;

  /// The spec's row height.
  static const rowHeight = 48.0;
  static const monogramSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: height,
      key: Key('dashboardRecentRow-${transaction.id}'),
      child: Row(
        children: [
          InstitutionAvatar(name: transaction.label, size: monogramSize),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          // The label block takes ~7/10 of what's left rather than everything but the amount:
          // merchant names run long, and a label that ellipsizes hard against the figure
          // reads as one run of text. The gutter is the flex share, not a fixed gap.
          Expanded(
            flex: 7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.label,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  transaction.accountLabel,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Both capped at one line. This column is a flex share of a
                // card that is now the middle of three (`docs/design/04`
                // §Row 3 — Phase 2), and an amount or a date allowed to wrap
                // grows the row past the height the list measured for it.
                AmountText(
                  amountMinor: transaction.amountMinor,
                  currency: transaction.currency,
                  showPositiveSign: true,
                  maxLines: 1,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 1),
                Text(
                  DateFormat.yMd(locale).format(transaction.bookedDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
