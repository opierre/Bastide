import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transactions_repository.dart';
import '../domain/category.dart' show PickerCategory;
import '../domain/transaction.dart';

/// The active list filters, held separately from the loaded page so a filter
/// change is a single state transition the controller can watch and react to
/// — see [TransactionsController.build].
@immutable
class TransactionFilters {
  const TransactionFilters({
    this.accountId,
    this.dateFrom,
    this.dateTo,
    this.categoryId,
    this.needsReview,
    this.q = '',
    this.page = 1,
  });

  final String? accountId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? categoryId;

  /// `true` narrows to the review queue; `null`/`false` is the normal list.
  final bool? needsReview;
  final String q;
  final int page;

  TransactionFilters copyWith({
    String? accountId,
    bool clearAccountId = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDateRange = false,
    String? categoryId,
    bool clearCategoryId = false,
    bool? needsReview,
    bool clearNeedsReview = false,
    String? q,
    int? page,
  }) {
    return TransactionFilters(
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      needsReview: clearNeedsReview ? null : (needsReview ?? this.needsReview),
      q: q ?? this.q,
      page: page ?? this.page,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionFilters &&
          other.accountId == accountId &&
          other.dateFrom == dateFrom &&
          other.dateTo == dateTo &&
          other.categoryId == categoryId &&
          other.needsReview == needsReview &&
          other.q == q &&
          other.page == page);

  @override
  int get hashCode =>
      Object.hash(accountId, dateFrom, dateTo, categoryId, needsReview, q, page);
}

class TransactionFiltersNotifier extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() => const TransactionFilters();

  void setAccount(String? accountId) =>
      state = state.copyWith(accountId: accountId, clearAccountId: accountId == null, page: 1);

  void setDateRange(DateTime? from, DateTime? to) => state = state.copyWith(
    dateFrom: from,
    dateTo: to,
    clearDateRange: from == null && to == null,
    page: 1,
  );

  void setCategory(String? categoryId) => state = state.copyWith(
    categoryId: categoryId,
    clearCategoryId: categoryId == null,
    page: 1,
  );

  void setNeedsReview(bool? value) =>
      state = state.copyWith(needsReview: value, clearNeedsReview: value == null, page: 1);

  void setQuery(String q) => state = state.copyWith(q: q, page: 1);

  void setPage(int page) => state = state.copyWith(page: page);
}

final transactionFiltersProvider =
    NotifierProvider<TransactionFiltersNotifier, TransactionFilters>(
      TransactionFiltersNotifier.new,
    );

/// The filtered, paginated transaction list. Rebuilds from the API whenever
/// [transactionFiltersProvider] changes — the filter bar and pager only ever
/// touch that provider, never this one directly.
class TransactionsController extends AsyncNotifier<TransactionsPage> {
  @override
  Future<TransactionsPage> build() {
    final filters = ref.watch(transactionFiltersProvider);
    return _fetch(filters);
  }

  Future<TransactionsPage> _fetch(TransactionFilters filters) {
    return ref
        .read(transactionsRepositoryProvider)
        .list(
          accountId: filters.accountId,
          dateFrom: filters.dateFrom,
          dateTo: filters.dateTo,
          categoryId: filters.categoryId,
          needsReview: filters.needsReview,
          q: filters.q,
          page: filters.page,
        );
  }

  Future<void> refresh() async {
    final filters = ref.read(transactionFiltersProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(filters));
  }

  /// Patches [transaction]'s category. Sets `source=user` server-side and
  /// clears `needs_review` — see the ai-categorization skill.
  Future<void> updateCategory(Transaction transaction, String categoryId) async {
    final updated = await ref
        .read(transactionsRepositoryProvider)
        .update(transaction.id, categoryId: categoryId);
    _replace(updated);
  }

  /// Applies [categoryId] to [transaction] and creates a matching rule so the
  /// rule engine picks up transactions like it automatically from now on.
  Future<void> alwaysCategorizeLike(Transaction transaction, String categoryId) async {
    final merchant = transaction.merchant?.trim();
    final hasMerchant = merchant != null && merchant.isNotEmpty;
    await ref
        .read(transactionsRepositoryProvider)
        .alwaysCategorizeAs(
          matchField: hasMerchant ? 'merchant' : 'description_clean',
          pattern: hasMerchant ? merchant : transaction.descriptionClean,
          categoryId: categoryId,
        );
    await updateCategory(transaction, categoryId);
  }

  void _replace(Transaction updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      TransactionsPage(
        items: [
          for (final transaction in current.items)
            if (transaction.id == updated.id) updated else transaction,
        ],
        page: current.page,
        pageSize: current.pageSize,
        total: current.total,
      ),
    );
  }
}

final transactionsControllerProvider =
    AsyncNotifierProvider<TransactionsController, TransactionsPage>(
      TransactionsController.new,
    );

/// The category catalog for the picker (system + the caller's own). Loaded
/// once per session — categories change rarely enough that a `FutureProvider`
/// without manual refresh is the right amount of machinery here.
final transactionCategoriesProvider = FutureProvider<List<PickerCategory>>((ref) {
  return ref.read(transactionsRepositoryProvider).listCategories();
});
