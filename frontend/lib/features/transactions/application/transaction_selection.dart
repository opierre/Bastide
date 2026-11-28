import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/domain/category.dart' show AppCategory;
import '../data/transactions_repository.dart';
import '../domain/transaction.dart';
import 'transactions_controller.dart';

/// The operation the inspector shows, by id; `null` when none is selected.
///
/// Held by id rather than as a row so a reload of the page (a recategorized
/// row, a quiet refresh) keeps the selection on the fresh copy, and it
/// survives leaving and returning to the panel within a session
/// (`docs/design/07-transactions.md` §Behaviour).
class SelectedTransaction extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  /// Moves the selection [delta] rows through [items] (`↑` `↓`), stopping at
  /// either end. With nothing selected, `↓` lands on the first row and `↑` on
  /// the last.
  void move(List<Transaction> items, int delta) {
    if (items.isEmpty) return;
    final index = items.indexWhere((item) => item.id == state);
    if (index == -1) {
      state = (delta > 0 ? items.first : items.last).id;
      return;
    }
    state = items[(index + delta).clamp(0, items.length - 1)].id;
  }
}

final selectedTransactionProvider =
    NotifierProvider<SelectedTransaction, String?>(SelectedTransaction.new);

/// Opens Transactions on one operation, from a deep link (an account's
/// « Opérations » row).
///
/// The list is narrowed to that one operation, whatever the filters were, and
/// it is selected for the inspector: the row the user clicked, without the
/// rest of its day beside it. An unknown id, or a failed read, leaves the
/// panel as it was.
class TransactionDeepLink extends Notifier<void> {
  @override
  void build() {}

  Future<void> open(String id) async {
    try {
      // Read first, so an id that leads nowhere never replaces the filters.
      await ref.read(transactionsRepositoryProvider).get(id);
    } catch (_) {
      // Unknown id or unreachable sidecar alike: leave the panel as it was.
      return;
    }
    ref.read(transactionFiltersProvider.notifier).showOperation(id);
    ref.read(selectedTransactionProvider.notifier).select(id);
  }
}

final transactionDeepLinkProvider = NotifierProvider<TransactionDeepLink, void>(
  TransactionDeepLink.new,
);

/// The selected operation on the page shown, or `null` when none is selected
/// or the selected one is not on this page.
final selectedTransactionOnPageProvider = Provider<Transaction?>((ref) {
  final id = ref.watch(selectedTransactionProvider);
  if (id == null) return null;
  final page = ref.watch(transactionsControllerProvider).value;
  return page?.items.where((item) => item.id == id).firstOrNull;
});

/// What the inspector shows around an operation: its import, the rule that
/// filed it, its series, the merchant's earlier operations. Re-read after any
/// edit, since a recategorization changes which rule filed the row.
final transactionContextProvider = FutureProvider.autoDispose
    .family<TransactionContext, String>((ref, id) {
      ref.watch(transactionEditsProvider);
      return ref.read(transactionsRepositoryProvider).context(id);
    });

/// The operations of one day under its group row (`00` §7 Group row).
@immutable
class TransactionDay {
  const TransactionDay({required this.date, required this.items});

  final DateTime date;
  final List<Transaction> items;
}

/// Splits a page, already newest first, into its days in the same order.
List<TransactionDay> groupByDay(List<Transaction> items) {
  final days = <TransactionDay>[];
  for (final item in items) {
    final booked = item.bookedDate;
    final date = DateTime(booked.year, booked.month, booked.day);
    if (days.isNotEmpty && days.last.date == date) {
      days.last.items.add(item);
    } else {
      days.add(TransactionDay(date: date, items: [item]));
    }
  }
  return days;
}

/// A category and, when it is a subcategory, the top-level category above it.
@immutable
class CategoryLineage {
  const CategoryLineage({required this.top, this.sub});

  final AppCategory top;
  final AppCategory? sub;
}

/// Where category [id] sits in [catalog]; `null` when the catalog does not
/// hold it (not loaded yet, or a category since deleted).
CategoryLineage? categoryLineage(List<AppCategory> catalog, String id) {
  final byId = {for (final category in catalog) category.id: category};
  final category = byId[id];
  if (category == null) return null;
  final parent = category.parentId == null ? null : byId[category.parentId];
  return parent == null
      ? CategoryLineage(top: category)
      : CategoryLineage(top: parent, sub: category);
}

/// The catalog in picker order: each top-level category followed by its
/// subcategories.
List<CategoryLineage> pickerOrder(List<AppCategory> catalog) {
  final children = <String, List<AppCategory>>{};
  for (final category in catalog) {
    final parent = category.parentId;
    if (parent != null) (children[parent] ??= []).add(category);
  }
  return [
    for (final top in catalog)
      if (top.parentId == null) ...[
        CategoryLineage(top: top),
        for (final sub in children[top.id] ?? const <AppCategory>[])
          CategoryLineage(top: top, sub: sub),
      ],
  ];
}
