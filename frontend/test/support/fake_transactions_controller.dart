import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A no-network `TransactionsController` double for widget tests: holds a
/// fixed page and records category-edit calls without touching the real API
/// client — see `fake_accounts_controller.dart` for the same pattern.
class FakeTransactionsController extends TransactionsController {
  FakeTransactionsController({required this.initialPage});

  final TransactionsPage initialPage;

  final updateCategoryCalls = <({String transactionId, String categoryId})>[];
  int refreshQuietlyCalls = 0;

  Object? errorOnUpdate;

  @override
  Future<TransactionsPage> build() async => initialPage;

  @override
  Future<void> updateCategory(
    Transaction transaction,
    String categoryId,
  ) async {
    updateCategoryCalls.add((
      transactionId: transaction.id,
      categoryId: categoryId,
    ));
    if (errorOnUpdate != null) throw errorOnUpdate!;
    _applyCategory(transaction.id, categoryId);
  }

  @override
  Future<void> refreshQuietly() async => refreshQuietlyCalls++;

  final excludeCalls = <({String transactionId, bool excluded})>[];

  @override
  Future<void> setExcludedFromTotals(
    Transaction transaction, {
    required bool excluded,
  }) async {
    excludeCalls.add((transactionId: transaction.id, excluded: excluded));
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      TransactionsPage(
        items: [
          for (final item in current.items)
            if (item.id == transaction.id)
              item.copyWith(excludedFromTotals: excluded)
            else
              item,
        ],
        page: current.page,
        pageSize: current.pageSize,
        total: current.total,
        netMinor: current.netMinor,
      ),
    );
  }

  void _applyCategory(String transactionId, String categoryId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      TransactionsPage(
        items: [
          for (final transaction in current.items)
            if (transaction.id == transactionId)
              transaction.copyWith(
                category: TransactionCategory(
                  id: categoryId,
                  name: 'category.food.groceries',
                  kind: 'expense',
                  icon: 'shopping_cart',
                  color: 'cat3',
                ),
                categorizationSource: CategorizationSource.user,
                needsReview: false,
              )
            else
              transaction,
        ],
        page: current.page,
        pageSize: current.pageSize,
        total: current.total,
      ),
    );
  }
}
