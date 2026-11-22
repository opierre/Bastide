import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_trends.dart';

/// « Activité récente » (`docs/design/04-dashboard.md` §5a): a table without
/// header, as many 36 px rows as the height allows (six at 900 px). Each row:
/// monogram and label, the account in `textTertiary`, the signed amount. A
/// raw bank label is set in Geist Mono behind the « ? » monogram.
class RecentActivity extends StatelessWidget {
  const RecentActivity({
    super.key,
    required this.transactions,
    required this.onViewAll,
    required this.onOpen,
  });

  final List<RecentTransaction> transactions;
  final VoidCallback onViewAll;
  final ValueChanged<RecentTransaction> onOpen;

  static const _columns = [
    AppTableColumn(label: '', flex: 3),
    AppTableColumn(label: '', flex: 2),
    AppTableColumn(label: '', width: 120, numeric: true),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      key: const Key('dashboardRecentActivity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.dashboardRecentActivityTitle,
          trailing: AppLink(
            key: const Key('dashboardViewAllTransactions'),
            label: l10n.dashboardViewAllTransactions,
            onTap: onViewAll,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fits = constraints.hasBoundedHeight
                  ? (constraints.maxHeight ~/ AppSizes.tableRow)
                  : transactions.length;
              final shown = transactions.take(fits);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final transaction in shown)
                    _ActivityRow(
                      transaction: transaction,
                      columns: _columns,
                      onTap: () => onOpen(transaction),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.transaction,
    required this.columns,
    required this.onTap,
  });

  final RecentTransaction transaction;
  final List<AppTableColumn> columns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final raw = transaction.isRawLabel;

    return AppTableRow(
      key: Key('dashboardRecentRow-${transaction.id}'),
      columns: columns,
      onTap: onTap,
      cells: [
        Row(
          children: [
            InstitutionAvatar(
              // An unrecognised merchant is « ? », not the initials of the
              // bank's raw wording.
              name: raw ? '' : transaction.label,
              logo: transaction.logo,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                transaction.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: raw
                    ? context.textStyles.mono.copyWith(color: colors.text)
                    : null,
              ),
            ),
          ],
        ),
        Text(
          transaction.accountLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
        ),
        AmountText(
          amountMinor: transaction.amountMinor,
          currency: transaction.currency,
          showPositiveSign: true,
          maxLines: 1,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}
