import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/search_pill.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account.dart';
import '../../imports/presentation/imports_screen.dart';
import '../application/transactions_controller.dart';
import '../../categories/domain/category.dart';
import '../domain/transaction.dart';
import 'date_range_modal.dart';
import 'review_queue.dart';
import 'transaction_error_localizer.dart';
import 'transaction_row.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  static const path = '/transactions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pageAsync = ref.watch(transactionsControllerProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final hasActiveFilter =
        filters.accountId != null ||
        filters.dateFrom != null ||
        filters.dateTo != null ||
        filters.categoryId != null ||
        filters.needsReview != null ||
        filters.q.trim().isNotEmpty;

    return Padding(
      key: const Key('screen-transactions'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.contentX,
        AppSpacing.contentTopFiltered,
        AppSpacing.contentX,
        AppSpacing.contentY,
      ),
      child: switch (pageAsync) {
        AsyncData(:final value) when value.total == 0 && !hasActiveFilter =>
          _EmptyState(onGoToImports: () => context.go(ImportsScreen.path)),
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FilterBar(),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: value.items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.transactionsSearchEmpty,
                        key: const Key('transactionsSearchEmpty'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : filters.needsReview == true
                  ? ReviewQueue(items: value.items, total: value.total)
                  : _TransactionsListCard(page: value, filters: filters),
            ),
          ],
        ),
        AsyncError(:final error) => ErrorStateView(
          message: localizeTransactionError(l10n, error),
          messageKey: const Key('transactionsErrorText'),
          retryLabel: l10n.transactionsRetry,
          retryKey: const Key('transactionsRetryButton'),
          onRetry: () =>
              ref.read(transactionsControllerProvider.notifier).refresh(),
        ),
        _ => const Padding(
          key: Key('transactionsLoadingIndicator'),
          padding: EdgeInsets.only(top: 32),
          child: SkeletonList(),
        ),
      },
    );
  }
}

/// The transactions panel's contribution to the top bar: the 300px search
/// pill named in `docs/design/07-transactions.md`.
class TransactionsTopBarActions extends ConsumerWidget {
  const TransactionsTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return SearchPill(
      key: const Key('transactionsSearchField'),
      hint: l10n.transactionsSearchHint,
      width: 300,
      initialValue: ref.read(transactionFiltersProvider).q,
      onChanged: (value) =>
          ref.read(transactionFiltersProvider.notifier).setQuery(value),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGoToImports});

  final VoidCallback onGoToImports;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      icon: Icons.receipt_long_outlined,
      title: l10n.transactionsEmptyTitle,
      message: l10n.transactionsEmptyBody,
      action: OutlinedButton(
        key: const Key('transactionsGoToImportsButton'),
        onPressed: onGoToImports,
        child: Text(l10n.transactionsGoToImports),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(transactionFiltersProvider);
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final categories =
        ref.watch(transactionCategoriesProvider).value ?? const <AppCategory>[];
    final notifier = ref.read(transactionFiltersProvider.notifier);

    return Row(
      children: [
        _AccountFilterPill(
          accounts: accounts,
          selectedId: filters.accountId,
          onChanged: notifier.setAccount,
        ),
        const SizedBox(width: AppSpacing.sm),
        _DateRangeFilterPill(
          from: filters.dateFrom,
          to: filters.dateTo,
          onChanged: notifier.setDateRange,
        ),
        const SizedBox(width: AppSpacing.sm),
        _CategoryFilterPill(
          categories: categories,
          selectedId: filters.categoryId,
          onChanged: notifier.setCategory,
        ),
        const Spacer(),
        Text(
          l10n.transactionsNeedsReviewLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: AppSpacing.sm),
        _NeedsReviewToggle(
          value: filters.needsReview == true,
          onChanged: (value) => notifier.setNeedsReview(value ? true : null),
        ),
      ],
    );
  }
}

class _FilterPillButton extends StatelessWidget {
  const _FilterPillButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        height: AppChrome.controlPillHeight,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs + 1),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountFilterPill extends StatelessWidget {
  const _AccountFilterPill({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = accounts
        .where((account) => account.id == selectedId)
        .firstOrNull;

    return PopupMenuButton<String?>(
      key: const Key('transactionsAccountFilter'),
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(l10n.transactionsFilterAllAccounts),
        ),
        for (final account in accounts)
          PopupMenuItem<String?>(value: account.id, child: Text(account.name)),
      ],
      child: _FilterPillButton(
        label: selected?.name ?? l10n.transactionsFilterAllAccounts,
        onTap: () {},
      ),
    );
  }
}

class _CategoryFilterPill extends StatelessWidget {
  const _CategoryFilterPill({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final List<AppCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = categories
        .where((category) => category.id == selectedId)
        .firstOrNull;

    return PopupMenuButton<String?>(
      key: const Key('transactionsCategoryFilter'),
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(l10n.transactionsFilterAllCategories),
        ),
        for (final category in categories)
          PopupMenuItem<String?>(
            value: category.id,
            child: Text(localizedCategoryName(l10n, category.name)),
          ),
      ],
      child: _FilterPillButton(
        label: selected == null
            ? l10n.transactionsFilterAllCategories
            : localizedCategoryName(l10n, selected.name),
        onTap: () {},
      ),
    );
  }
}

class _DateRangeFilterPill extends StatelessWidget {
  const _DateRangeFilterPill({
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final label = (from == null || to == null)
        ? l10n.transactionsFilterAllDates
        : '${DateFormat.yMd(locale).format(from!)} – ${DateFormat.yMd(locale).format(to!)}';

    return _FilterPillButton(
      icon: Icons.calendar_today_outlined,
      label: label,
      onTap: () async {
        final range = await showTransactionDateRange(
          context,
          from: from,
          to: to,
        );
        if (range != null) onChanged(range.$1, range.$2);
      },
    );
  }
}

/// Inset 34×20 toggle track with an explicit knob, per the design-system's
/// (still-to-build) `Toggle` component — kept local to this panel rather than
/// promoted to `core/widgets/` since no other feature needs it yet.
class _NeedsReviewToggle extends StatelessWidget {
  const _NeedsReviewToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('transactionsNeedsReviewToggle'),
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: Duration.zero,
        width: 34,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? AppColors.iris : AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TransactionsListCard extends ConsumerWidget {
  const _TransactionsListCard({required this.page, required this.filters});

  final TransactionsPage page;
  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final accountNames = {
      for (final account in accounts) account.id: account.name,
    };
    final from = page.total == 0 ? 0 : ((page.page - 1) * page.pageSize) + 1;
    final to = ((page.page - 1) * page.pageSize) + page.items.length;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              key: const Key('transactionsList'),
              itemCount: page.items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (context, index) {
                final transaction = page.items[index];
                return TransactionRow(
                  transaction: transaction,
                  accountName: accountNames[transaction.accountId] ?? '',
                );
              },
            ),
          ),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Text(
                  l10n.transactionsPager(from, to, page.total),
                  key: const Key('transactionsPagerLabel'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('transactionsPagerPrev'),
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  onPressed: page.page > 1
                      ? () => ref
                            .read(transactionFiltersProvider.notifier)
                            .setPage(page.page - 1)
                      : null,
                ),
                IconButton(
                  key: const Key('transactionsPagerNext'),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  onPressed: page.page < page.totalPages
                      ? () => ref
                            .read(transactionFiltersProvider.notifier)
                            .setPage(page.page + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
