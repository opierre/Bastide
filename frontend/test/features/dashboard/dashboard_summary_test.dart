import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/domain/dashboard_summary.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_fixtures.dart';

CategoryBreakdown _category(String id, int amountMinor, double pct) =>
    CategoryBreakdown(
      categoryId: id,
      name: 'category.other',
      hue: 'cat0',
      amountMinor: amountMinor,
      pct: pct,
    );

void main() {
  group('rankedSpending', () {
    test('ranks largest first and measures bars against the largest', () {
      final rows = specSummary(
        byCategory: [
          _category('small', 2500, 25),
          _category('large', 7500, 75),
        ],
      ).rankedSpending;

      expect(rows.map((r) => r.category?.categoryId), ['large', 'small']);
      expect(rows.first.barFraction, 1);
      expect(rows.last.barFraction, closeTo(1 / 3, 1e-9));
    });

    test('folds the smallest into « Autres » past eight rows', () {
      final rows = specSummary(
        byCategory: [
          for (var i = 0; i < 10; i++) _category('c$i', 1000 * (10 - i), 10),
        ],
      ).rankedSpending;

      expect(rows, hasLength(DashboardSummary.maxSpendingRows));
      expect(rows.last.isOthers, isTrue);
      // c7, c8 and c9: 3 000 + 2 000 + 1 000.
      expect(rows.last.amountMinor, 6000);
      expect(rows.last.pct, 30);
      expect(rows.take(7).every((r) => !r.isOthers), isTrue);
    });

    test('a month without spending has no rows', () {
      expect(specSummary(byCategory: const []).rankedSpending, isEmpty);
    });
  });

  group('savings rate', () {
    test('sits on a scale of 0 to twice the goal', () {
      expect(
        specSummary(savingsRate: 0.1).savingsRateMeterFraction,
        closeTo(0.25, 1e-9),
      );
      expect(specSummary(savingsRate: 0.6).savingsRateMeterFraction, 1);
      expect(specSummary(savingsRate: -0.2).savingsRateMeterFraction, 0);
    });

    test('has no value without income', () {
      final summary = specSummary(incomeMinor: 0, savingsRate: 0);
      expect(summary.hasSavingsRate, isFalse);
      expect(summary.savingsGoalReached, isFalse);
    });
  });

  test('a category row filters Transactions on that category and month', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    focusTransactionsOnCategory(
      container.read(transactionFiltersProvider.notifier),
      categoryId: 'c1',
      month: DateTime(2026, 2),
    );

    final filters = container.read(transactionFiltersProvider);
    expect(filters.categoryId, 'c1');
    expect(filters.dateFrom, DateTime(2026, 2));
    expect(filters.dateTo, DateTime(2026, 2, 28));
  });
}
