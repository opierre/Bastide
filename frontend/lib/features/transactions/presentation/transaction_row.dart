import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/transaction.dart';
import 'category_picker.dart';

/// A single 52px transaction row: merchant monogram, a two-line merchant +
/// account block, the category chip, the booked date, and the signed amount
/// — see `docs/design/07-transactions.md`.
class TransactionRow extends ConsumerWidget {
  const TransactionRow({super.key, required this.transaction, required this.accountName});

  final Transaction transaction;
  final String accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final label = transaction.merchant?.trim().isNotEmpty ?? false
        ? transaction.merchant!
        : transaction.descriptionClean;

    return _HoverableRow(
      key: Key('transactionRow-${transaction.id}'),
      child: Row(
        children: [
          InstitutionAvatar(name: label, size: 30),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          SizedBox(
            width: 290,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  accountName,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // A merchant name ellipsizes at the edge of its 290px block, so
          // without a gutter here a long label runs straight into the category
          // pill and the two read as one run of text.
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (chipContext) => transaction.category == null
                    ? CategoryChip.uncategorized(
                        key: const Key('transactionRowCategoryChip'),
                        label: l10n.categoryUncategorized,
                        onTap: () => showCategoryPicker(chipContext, ref, transaction: transaction),
                      )
                    : CategoryChip(
                        key: const Key('transactionRowCategoryChip'),
                        label: localizedCategoryName(l10n, transaction.category!.name),
                        slug: categorySlugFor(
                          name: transaction.category!.name,
                          kind: transaction.category!.kind,
                        ),
                        onTap: () => showCategoryPicker(chipContext, ref, transaction: transaction),
                      ),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              DateFormat.yMd(locale).format(transaction.bookedDate),
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerRight,
              child: AmountText(
                amountMinor: transaction.amountMinor,
                currency: transaction.currency,
                showPositiveSign: true,
                style: textTheme.bodyMedium!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Instant-fill row hover — the spec allows no transition here (see the
/// design-system skill's motion rules), so this just swaps a background color
/// on pointer enter/exit.
class _HoverableRow extends StatefulWidget {
  const _HoverableRow({super.key, required this.child});

  final Widget child;

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        color: _hovered ? AppColors.surfaceRowHover : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
