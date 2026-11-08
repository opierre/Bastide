import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../recurring/presentation/mark_recurring_dialog.dart';
import '../domain/transaction.dart';
import 'category_picker.dart';

/// How wide the merchant + account block is allowed to grow before it ellipsizes. Generous
/// enough for the long descriptions French banks emit, while still leaving the category pill,
/// the date, and the amount on screen at the panel's narrowest.
const _labelMaxWidth = 420.0;

/// A single 52px transaction row: merchant monogram, a two-line merchant +
/// memo/account block, the category chip, the booked date, and the signed amount
/// — see `docs/design/07-transactions.md`.
class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    required this.accountName,
    this.accountIcon,
  });

  final Transaction transaction;
  final String accountName;

  /// A glyph leading the secondary line, marking the account the row comes
  /// from — the account detail's list uses it for a linked card's rows.
  final IconData? accountIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final label = transaction.merchant?.trim().isNotEmpty ?? false
        ? transaction.merchant!
        : transaction.descriptionClean;
    // The bank's memo is the more informative half of the secondary line, so it leads
    // and the account follows it. The separator only appears between two present
    // halves — a row with no memo reads as the account alone, never as a stray dot.
    final memo = transaction.memo?.trim() ?? '';
    final subtitle = switch ((memo.isEmpty, accountName.isEmpty)) {
      (true, _) => accountName,
      (false, true) => memo,
      _ => l10n.transactionRowMemoAndAccount(memo, accountName),
    };

    return _HoverableRow(
      key: Key('transactionRow-${transaction.id}'),
      child: Row(
        children: [
          InstitutionAvatar(name: label, size: 30, logo: transaction.logo),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          // The label block is *tight* (Expanded, not Flexible) up to [_labelMaxWidth],
          // so it always occupies the same width regardless of how short the merchant
          // name is — the category pill starts at the same x on every row and the
          // pills read as one aligned column down the panel. It still shrinks below
          // the cap on narrow layouts, same as before.
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _labelMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (accountIcon != null) ...[
                              Icon(
                                accountIcon,
                                key: const Key('transactionRowAccountIcon'),
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            Flexible(
                              child: Text(
                                subtitle,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Deliberately wider than the row's other gutters — the pill needs to
                // read as its own column, not as a continuation of the merchant text.
                const SizedBox(width: AppSpacing.xl),
                Builder(
                  builder: (chipContext) => transaction.category == null
                      ? CategoryChip.uncategorized(
                          key: const Key('transactionRowCategoryChip'),
                          label: l10n.categoryUncategorized,
                          onTap: () => showCategoryPicker(
                            chipContext,
                            ref,
                            transaction: transaction,
                          ),
                        )
                      : CategoryChip(
                          key: const Key('transactionRowCategoryChip'),
                          label: localizedCategoryName(
                            l10n,
                            transaction.category!.name,
                          ),
                          slug: categorySlugFor(
                            name: transaction.category!.name,
                            kind: transaction.category!.kind,
                          ),
                          onTap: () => showCategoryPicker(
                            chipContext,
                            ref,
                            transaction: transaction,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // A fixed slot on every row, so the date column stays aligned whether
          // or not the row offers the action. Outflows only: a subscription is
          // something paid, and the server refuses a preview for an inflow.
          SizedBox(
            width: 28,
            child: transaction.amountMinor < 0
                ? _RecurringButton(transaction: transaction)
                : null,
          ),
          // Wider than the row's other gutters: the amount column right-aligns its
          // tabular figures, so for most everyday amounts (one or two digits before
          // the decimal) the date→amount gap reads bigger than a plain AppSpacing.md
          // gutter would. This closes that visual mismatch without needing the exact
          // amount's width, which varies row to row.
          const SizedBox(width: AppSpacing.xl),
          SizedBox(
            width: 90,
            child: Text(
              DateFormat.yMd(locale).format(transaction.bookedDate),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
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
                // Bolder and a step larger than the merchant line (titleSmall)
                // so the signed amount reads as the row's headline figure,
                // not body text — see the design-system skill's type scale.
                style: textTheme.titleMedium!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The row's recurring action. On a charge no series tracks yet it is a quiet
/// glyph that opens « Marquer comme récurrent »; on one that already belongs to
/// a series it sits on an iris plate — the cycle glyph on iris is what
/// Abonnements uses for a series — and opens that series directly, so the
/// state is carried by the plate and the tooltip as well as by the hue.
class _RecurringButton extends ConsumerWidget {
  const _RecurringButton({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final seriesId = transaction.recurringSeriesId;
    final inSeries = seriesId != null;
    return IconButton(
      key: Key(
        inSeries
            ? 'transactionRowOpenRecurringSeries'
            : 'transactionRowMarkRecurring',
      ),
      tooltip: inSeries
          ? l10n.markRecurringOpenSeriesAction
          : l10n.markRecurringAction,
      onPressed: () => inSeries
          ? openRecurringSeries(context, ref, seriesId: seriesId)
          : showMarkRecurringDialog(
              context,
              ref,
              transactionId: transaction.id,
            ),
      icon: const Icon(Icons.repeat_rounded),
      iconSize: 16,
      color: inSeries ? AppColors.iris : AppColors.textDisabled,
      hoverColor: AppColors.irisSoft,
      style: inSeries
          ? IconButton.styleFrom(backgroundColor: AppColors.irisSoft)
          : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
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
