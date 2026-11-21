import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_tabs.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../application/review_count_provider.dart';
import '../application/transaction_selection.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';
import 'review_queue.dart';
import 'transaction_error_localizer.dart';
import 'transaction_inspector.dart';
import 'transactions_list_pane.dart';

/// The Transactions panel (`docs/design/07-transactions.md`), flush: the tabs
/// « Toutes » and « À vérifier », then the selected tab's body. « Toutes » is
/// the list pane and the inspector of the selected operation; « À vérifier »
/// is the review queue.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  static const path = '/transactions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pageAsync = ref.watch(transactionsControllerProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final reviewCount = ref.watch(reviewCountProvider).value ?? 0;

    // No transaction at all: the empty state alone, without tabs or filters.
    final isEmpty = switch (pageAsync) {
      AsyncData(:final value) =>
        value.total == 0 &&
            !filters.isReviewTab &&
            !filters.hasListFilter &&
            reviewCount == 0,
      _ => false,
    };
    if (isEmpty) {
      return Padding(
        key: const Key('screen-transactions'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageX,
          vertical: AppSpacing.pageY,
        ),
        child: EmptyStateView(
          key: const Key('transactionsEmptyState'),
          title: l10n.transactionsEmptyTitle,
          message: l10n.transactionsEmptyBody,
          action: PrimaryButton(
            key: const Key('transactionsGoToImportsButton'),
            label: l10n.transactionsGoToImports,
            onPressed: () => context.go(ImportsScreen.path),
          ),
        ),
      );
    }

    return Column(
      key: const Key('screen-transactions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
          child: AppTabs<bool>(
            key: const Key('transactionsTabs'),
            value: filters.isReviewTab,
            onChanged: (review) => ref
                .read(transactionFiltersProvider.notifier)
                .setNeedsReview(review ? true : null),
            tabs: [
              AppTab(value: false, label: l10n.transactionsTabAll),
              AppTab(
                value: true,
                label: l10n.transactionsNeedsReviewLabel,
                // Hidden at 0 (`07` §Layout).
                count: reviewCount == 0 ? null : '$reviewCount',
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (pageAsync) {
            AsyncData(:final value) =>
              filters.isReviewTab
                  ? ReviewQueue(items: value.items, total: value.total)
                  : _AllTab(page: value),
            AsyncError(:final error) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageX,
                vertical: AppSpacing.pageY,
              ),
              child: ErrorStateView(
                message: localizeTransactionError(l10n, error),
                messageKey: const Key('transactionsErrorText'),
                retryLabel: l10n.transactionsRetry,
                retryKey: const Key('transactionsRetryButton'),
                onRetry: () =>
                    ref.read(transactionsControllerProvider.notifier).refresh(),
              ),
            ),
            _ => _TransactionsSkeleton(withInspector: !filters.isReviewTab),
          },
        ),
      ],
    );
  }
}

/// The panel's contribution to the title bar: the search field (« Rechercher »,
/// description and merchant; `Ctrl K` focuses it).
class TransactionsTopBarActions extends ConsumerWidget {
  const TransactionsTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppSearchField(
      key: const Key('transactionsSearchField'),
      hint: l10n.transactionsSearchHint,
      initialValue: ref.read(transactionFiltersProvider).q,
      onChanged: (value) =>
          ref.read(transactionFiltersProvider.notifier).setQuery(value),
    );
  }
}

/// « Toutes »: the list pane, flexible, and the 440 px inspector.
class _AllTab extends ConsumerWidget {
  const _AllTab({required this.page});

  final TransactionsPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTransactionOnPageProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: TransactionsListPane(page: page)),
        if (selected != null)
          TransactionInspector(transaction: selected)
        else
          const EmptyTransactionInspector(),
      ],
    );
  }
}

/// Loading: the silhouette of the filter row, the rows and, on « Toutes », the
/// inspector's ground (`00` §7 States of a panel).
class _TransactionsSkeleton extends StatelessWidget {
  const _TransactionsSkeleton({required this.withInspector});

  final bool withInspector;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SkeletonPulse(
      key: const Key('transactionsLoadingIndicator'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageX,
                vertical: AppTransactions.filterRowY,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBlock(
                    height: AppSizes.toolbarSelect,
                    width: AppTransactions.filterMaxWidth * 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < 8; i++) ...[
                    const SkeletonBlock(
                      height: AppSizes.tableRow - AppSpacing.sm,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          if (withInspector)
            Container(
              width: AppSizes.inspector,
              decoration: BoxDecoration(
                color: colors.rail,
                border: Border(left: BorderSide(color: colors.line)),
              ),
            ),
        ],
      ),
    );
  }
}
