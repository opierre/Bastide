import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transactions_repository.dart';
import '../../categories/domain/category.dart' show AppCategory;
import '../domain/transaction.dart';

/// Counts the edits that move what a transaction row shows: a category saved
/// through [TransactionsController], or a series linked or found gone (see
/// [refreshTransactionRows]).
///
/// Panels that list transactions outside the controller's page — the account
/// detail's recent operations — watch it to re-read their rows after an edit.
class TransactionEdits extends Notifier<int> {
  @override
  int build() => 0;

  void saved() => state++;
}

final transactionEditsProvider = NotifierProvider<TransactionEdits, int>(
  TransactionEdits.new,
);

/// Reloads every list of transaction rows — the Transactions panel's page and
/// the account detail's recent operations — after a change made elsewhere
/// moved what they show, such as a charge joining or losing a recurring series.
void refreshTransactionRows(Ref ref) {
  ref.invalidate(transactionsControllerProvider);
  ref.read(transactionEditsProvider.notifier).saved();
}

/// Whether [filters] widen their account to the deferred cards settled on it.
///
/// An account filter takes in those cards, so the panel lists what the account
/// detail lists (its « Voir tout » lands here). A card picked in the filter has
/// no cards of its own and reads alone. The settlement debit is filed as a
/// transfer, so the card's monthly debit and the purchases it pays are never
/// both counted as spending.
///
/// The « À vérifier » tab reads none of the list's filters (see
/// [TransactionFilters.isReviewTab]), so it never widens anything.
bool takesInLinkedCards(TransactionFilters filters) =>
    !filters.isReviewTab && filters.accountId != null;

/// An import narrowing the list to the operations it added. Carries the
/// import's file name so the filter row can name it without loading the
/// import history.
@immutable
class ImportBatchFilter {
  const ImportBatchFilter({required this.id, required this.fileName});

  final String id;
  final String fileName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportBatchFilter &&
          other.id == id &&
          other.fileName == fileName);

  @override
  int get hashCode => Object.hash(id, fileName);
}

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
    this.importBatch,
    this.q = '',
    this.page = 1,
  });

  final String? accountId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? categoryId;

  /// `true` is the « À vérifier » tab; `null`/`false` is « Toutes ».
  final bool? needsReview;

  /// Set from an import history row; shown as a removable chip.
  final ImportBatchFilter? importBatch;
  final String q;
  final int page;

  /// The « À vérifier » tab: the whole review queue, searched by [q] only.
  ///
  /// Its count is the one on the tab and in the sidebar, so the account,
  /// period and category picked on « Toutes » (whose filter row this tab does
  /// not show) must not narrow it unseen. They are kept, and apply again on
  /// the way back.
  bool get isReviewTab => needsReview == true;

  /// Whether « Toutes » is narrowed by anything the filter row or the search
  /// field set: what tells « no transaction at all » from « none of these ».
  bool get hasListFilter =>
      accountId != null ||
      dateFrom != null ||
      dateTo != null ||
      categoryId != null ||
      importBatch != null ||
      q.trim().isNotEmpty;

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
    ImportBatchFilter? importBatch,
    bool clearImportBatch = false,
    String? q,
    int? page,
  }) {
    return TransactionFilters(
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      needsReview: clearNeedsReview ? null : (needsReview ?? this.needsReview),
      importBatch: clearImportBatch ? null : (importBatch ?? this.importBatch),
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
          other.importBatch == importBatch &&
          other.q == q &&
          other.page == page);

  @override
  int get hashCode => Object.hash(
    accountId,
    dateFrom,
    dateTo,
    categoryId,
    needsReview,
    importBatch,
    q,
    page,
  );
}

class TransactionFiltersNotifier extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() => const TransactionFilters();

  /// An import belongs to one account, so moving to another account drops
  /// the import filter rather than leaving a list that can only be empty.
  void setAccount(String? accountId) => state = state.copyWith(
    accountId: accountId,
    clearAccountId: accountId == null,
    clearImportBatch: accountId != state.accountId,
    page: 1,
  );

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

  void setNeedsReview(bool? value) => state = state.copyWith(
    needsReview: value,
    clearNeedsReview: value == null,
    page: 1,
  );

  /// Narrows the list to exactly what [batch] added, in [accountId]. Every
  /// other filter is dropped: a leftover period, category or search would
  /// hide some of the import's operations.
  void showImport(ImportBatchFilter batch, {required String accountId}) =>
      state = TransactionFilters(accountId: accountId, importBatch: batch);

  void clearImport() => state = state.copyWith(clearImportBatch: true, page: 1);

  /// « Effacer les filtres »: lifts every filter of « Toutes » and the search,
  /// staying on the tab.
  void clearFilters() =>
      state = TransactionFilters(needsReview: state.needsReview);

  /// Sets every filter at once: a deep link lifting them all to show its
  /// operation, then putting them back when the operation is not found.
  void replace(TransactionFilters filters) => state = filters;

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
    final repository = ref.read(transactionsRepositoryProvider);
    if (filters.isReviewTab) {
      return repository.list(
        needsReview: true,
        q: filters.q,
        page: filters.page,
      );
    }
    return ref
        .read(transactionsRepositoryProvider)
        .list(
          accountId: filters.accountId,
          includeLinkedCards: takesInLinkedCards(filters),
          dateFrom: filters.dateFrom,
          dateTo: filters.dateTo,
          categoryId: filters.categoryId,
          needsReview: filters.needsReview,
          importBatchId: filters.importBatch?.id,
          q: filters.q,
          page: filters.page,
        );
  }

  Future<void> refresh() async {
    final filters = ref.read(transactionFiltersProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(filters));
  }

  /// Re-reads the current page without dropping to a loading state.
  ///
  /// What a categorization run needs: it commits a batch every couple of
  /// seconds, and rows leave the review queue as it does. Going through
  /// [refresh] would blank the list into a skeleton on every progress update, which is
  /// the opposite of the calm, non-blocking progress the panel promises — and
  /// a failed background refresh leaves the rows already on screen rather than
  /// replacing them with an error.
  Future<void> refreshQuietly() async {
    final filters = ref.read(transactionFiltersProvider);
    try {
      state = AsyncValue.data(await _fetch(filters));
    } catch (_) {
      // Deliberately swallowed: nobody asked for this refresh.
    }
  }

  /// Patches [transaction]'s category. Sets `source=user` server-side and
  /// clears `needs_review` — see the ai-categorization skill.
  Future<void> updateCategory(
    Transaction transaction,
    String categoryId,
  ) async {
    final updated = await ref
        .read(transactionsRepositoryProvider)
        .update(transaction.id, categoryId: categoryId);
    _replace(updated);
    ref.read(transactionEditsProvider.notifier).saved();
  }

  /// Accepts the model's proposal for [transaction] as-is.
  ///
  /// The same patch a correction makes, and deliberately so: a confirmed guess
  /// becomes `source = user`, because the user has now said it — the run that
  /// guessed it is no longer what the row rests on, and a later run must never
  /// reconsider it.
  Future<void> confirmProposal(Transaction transaction) async {
    final proposed = transaction.category;
    if (proposed == null) return;
    await updateCategory(transaction, proposed.id);
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
        netMinor: current.netMinor,
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
final transactionCategoriesProvider = FutureProvider<List<AppCategory>>((ref) {
  return ref.read(transactionsRepositoryProvider).listCategories();
});

/// The categories the list's category filter offers: main categories only.
/// Picking one also matches its sub-categories (the API widens the filter), so
/// listing them too would only make the menu long and hard to scan.
final transactionFilterCategoriesProvider = Provider<List<AppCategory>>((ref) {
  final categories =
      ref.watch(transactionCategoriesProvider).value ?? const <AppCategory>[];
  return [
    for (final category in categories)
      if (category.parentId == null) category,
  ];
});
