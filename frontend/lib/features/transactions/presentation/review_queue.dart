import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/transaction.dart';
import 'category_picker.dart';

/// The `needs_review=true` queue: an encouraging progress card over rows that
/// let the user confirm or correct each uncertain transaction, framed as
/// progress rather than a backlog — see `docs/design/07-transactions.md` and
/// the ai-categorization skill's human-review step.
class ReviewQueue extends StatelessWidget {
  const ReviewQueue({super.key, required this.items, required this.total});

  final List<Transaction> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.reviewQueueEmpty,
          key: const Key('reviewQueueEmpty'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressCard(total: total),
        const SizedBox(height: AppSpacing.gridGap),
        Expanded(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              key: const Key('reviewQueueList'),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (context, index) => _ReviewRow(transaction: items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.irisSoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.iris),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reviewQueueCount(total),
                  key: const Key('reviewQueueCount'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.reviewQueueEncouragement,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends ConsumerWidget {
  const _ReviewRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      key: Key('reviewRow-${transaction.id}'),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          InstitutionAvatar(name: transaction.descriptionRaw, size: 36),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Text(
              transaction.descriptionRaw,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Builder(
            builder: (chipContext) => CategoryChip.uncategorized(
              key: const Key('reviewRowCategoryChip'),
              label: l10n.categoryUncategorized,
              onTap: () => showCategoryPicker(chipContext, ref, transaction: transaction),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Builder(
            builder: (buttonContext) => InkWell(
              key: const Key('reviewRowAlwaysButton'),
              onTap: () => showCategoryPicker(
                buttonContext,
                ref,
                transaction: transaction,
                alwaysRule: true,
              ),
              child: Text(
                l10n.reviewAlwaysCategorize,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.iris),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerRight,
              child: AmountText(
                amountMinor: transaction.amountMinor,
                currency: transaction.currency,
                showPositiveSign: true,
                style: Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
