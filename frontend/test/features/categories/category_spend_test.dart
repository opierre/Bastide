import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/categories/application/category_spend_controller.dart';
import 'package:finstride/features/categories/data/categories_repository.dart';
import 'package:finstride/features/categories/domain/category.dart';
import 'package:finstride/features/categories/domain/category_spend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

AppCategory _category({required String id, String? parentId}) => AppCategory(
  id: id,
  userId: null,
  parentId: parentId,
  name: id,
  kind: 'expense',
  icon: 'sell',
  color: '#5AA9FF',
  isSystem: true,
);

CategoryNode _node(String id, [List<String> children = const []]) => CategoryNode(
  category: _category(id: id),
  children: [for (final child in children) _category(id: child, parentId: id)],
);

MonthlySpend _spend(Map<String, int> byCategoryId, {int totalMinor = 100000}) => MonthlySpend(
  month: DateTime(2026, 5),
  currency: 'EUR',
  totalMinor: totalMinor,
  byCategoryId: byCategoryId,
);

void main() {
  group('rollUpSpend', () {
    test('folds subcategory amounts into the parent, keeping the children their own', () {
      final view = rollUpSpend([
        _node('food', ['groceries', 'restaurants']),
      ], _spend({'food': 1000, 'groceries': 22000, 'restaurants': 17000}));

      // The parent stands for the whole group: its own 10 € plus 220 € and 170 €.
      expect(view.forCategory('food')!.amountMinor, 40000);
      expect(view.forCategory('groceries')!.amountMinor, 22000);
      expect(view.forCategory('restaurants')!.amountMinor, 17000);
    });

    test('takes shares against the month total, not against the rows it can see', () {
      // 400 € of a 1 000 € month — the other 600 € is uncategorized, and stays
      // out of the panel rather than being redistributed across the rows.
      final view = rollUpSpend([_node('food')], _spend({'food': 40000}));

      expect(view.forCategory('food')!.pct, closeTo(40.0, 0.001));
      expect(view.forCategory('food')!.fraction, closeTo(0.40, 0.001));
    });

    test('omits a category that spent nothing rather than recording a zero', () {
      final view = rollUpSpend([
        _node('income', ['salary']),
      ], _spend({'food': 40000}));

      expect(view.forCategory('income'), isNull);
      expect(view.forCategory('salary'), isNull);
      expect(view.byCategoryId, isEmpty);
    });

    test('a month with no expense at all yields shares of zero, not a division by it', () {
      final view = rollUpSpend([_node('food')], _spend({'food': 40000}, totalMinor: 0));

      expect(view.forCategory('food')!.amountMinor, 40000);
      expect(view.forCategory('food')!.pct, 0);
    });
  });

  group('CategoriesRepository.monthlySpend', () {
    late MockApiClient apiClient;
    late ProviderContainer container;

    setUp(() {
      apiClient = MockApiClient();
      container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);
    });

    void stubTransactions(List<Map<String, dynamic>> items) {
      when(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).thenAnswer((_) async => {'items': items});
    }

    test('asks for the latest month with data and drops the uncategorized bucket', () async {
      stubTransactions([
        {'booked_date': '2026-05-14'},
      ]);
      when(() => apiClient.get('/dashboard/summary', query: {'month': '2026-05'})).thenAnswer(
        (_) async => {
          'currency': 'EUR',
          'expense_minor': 100000,
          'by_category': [
            {
              'category_id': 'food',
              'name': 'category.food',
              'amount_minor': 40000,
              'pct': 40.0,
            },
            {
              'category_id': null,
              'name': 'category.other.uncategorized',
              'amount_minor': 60000,
              'pct': 60.0,
            },
          ],
        },
      );

      final spend = await container.read(categoriesRepositoryProvider).monthlySpend();

      expect(spend.month, DateTime(2026, 5));
      expect(spend.currency, 'EUR');
      expect(spend.totalMinor, 100000);
      expect(spend.byCategoryId, {'food': 40000});
    });

    test('falls back to the current month for a user with no transactions yet', () async {
      stubTransactions([]);
      final now = DateTime.now();
      final month =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}';
      when(() => apiClient.get('/dashboard/summary', query: {'month': month})).thenAnswer(
        (_) async => {'currency': 'EUR', 'expense_minor': 0, 'by_category': <dynamic>[]},
      );

      final spend = await container.read(categoriesRepositoryProvider).monthlySpend();

      expect(spend.month, DateTime(now.year, now.month));
      expect(spend.byCategoryId, isEmpty);
    });
  });
}
