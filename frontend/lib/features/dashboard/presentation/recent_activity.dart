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
          Text(l10n.dashboardRecentActivityTitle, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      l10n.dashboardRecentActivityEmpty,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  )
                : LayoutBuilder(
                    // 48px is the spec's row height and what the four drawn rows need. It is
                    // applied as a maximum rather than a fixed height: rows 1 and 2 are pinned
                    // (136 and 322), so on the 900px frame this card gets whatever is left,
                    // and four rows at a hard 48 overflow it by a few pixels once the title
                    // and the link are counted.
                    builder: (context, constraints) {
                      final height = constraints.hasBoundedHeight
                          ? math.min(
                              CompactTransactionRow.rowHeight,
                              constraints.maxHeight / transactions.length,
                            )
                          : CompactTransactionRow.rowHeight;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final transaction in transactions)
                            CompactTransactionRow(
                              transaction: transaction,
                              height: height,
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
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
          ),
        ],
      ),
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
          Expanded(
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
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                amountMinor: transaction.amountMinor,
                currency: transaction.currency,
                showPositiveSign: true,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 1),
              Text(
                DateFormat.yMd(locale).format(transaction.bookedDate),
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
