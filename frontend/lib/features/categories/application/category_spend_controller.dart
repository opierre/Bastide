import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/categories_repository.dart';
import '../domain/category.dart';
import '../domain/category_spend.dart';
import 'categories_controller.dart';

/// The month's raw expense split, straight off the API.
///
/// A [FutureProvider] rather than a controller: nothing in the panel writes to
/// it, and it reloads only when the whole provider is invalidated.
final monthlySpendProvider = FutureProvider<MonthlySpend>((ref) {
  return ref.read(categoriesRepositoryProvider).monthlySpend();
});

/// The spend figures the category rows draw, with subcategory amounts folded
/// into their parents.
///
/// Kept apart from [categoriesControllerProvider] on purpose: the catalog is
/// what the panel is *for*, and the bars are what it costs. A summary the
/// sidecar can't answer must not take the management view down with it — the
/// screen renders the tree from whichever of the two arrives, and simply leaves
/// the spend columns blank while this one is loading or failed.
final categorySpendProvider = Provider<AsyncValue<CategorySpendView>>((ref) {
  final tree = ref.watch(categoryTreeProvider);
  final spend = ref.watch(monthlySpendProvider);
  return spend.whenData((value) => rollUpSpend(tree.value ?? const <CategoryNode>[], value));
});

/// Folds each subcategory's expense into its parent and turns every amount into
/// its share of the month.
///
/// A parent row stands for its whole group, so « Alimentation » shows Courses +
/// Restaurants plus whatever was booked against the parent itself — a parent
/// showing only its own direct transactions would read as the cheapest line in
/// the panel while being the most expensive. The subcategory rows keep their own
/// amounts, so the group total is always visibly accounted for.
///
/// Shares are taken against the month's *whole* expense total, not against the
/// sum of the rows, so the figures match the dashboard's donut exactly and the
/// column doesn't quietly redistribute uncategorized spending across categories.
@visibleForTesting
CategorySpendView rollUpSpend(List<CategoryNode> nodes, MonthlySpend spend) {
  double share(int amount) => spend.totalMinor > 0 ? amount / spend.totalMinor * 100 : 0;

  final byCategoryId = <String, CategorySpend>{};
  for (final node in nodes) {
    var groupTotal = spend.byCategoryId[node.category.id] ?? 0;
    for (final child in node.children) {
      final childAmount = spend.byCategoryId[child.id] ?? 0;
      groupTotal += childAmount;
      if (childAmount > 0) {
        byCategoryId[child.id] = CategorySpend(
          amountMinor: childAmount,
          pct: share(childAmount),
        );
      }
    }
    if (groupTotal > 0) {
      byCategoryId[node.category.id] = CategorySpend(
        amountMinor: groupTotal,
        pct: share(groupTotal),
      );
    }
  }

  return CategorySpendView(
    month: spend.month,
    currency: spend.currency,
    byCategoryId: byCategoryId,
  );
}
