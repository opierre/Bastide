import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _transactionJson({
  String id = 't1',
  int amountMinor = -1250,
  bool needsReview = false,
  Map<String, dynamic>? category,
  String? merchant = 'Carrefour',
  String categorizationSource = 'rule',
}) => {
  'id': id,
  'account_id': 'a1',
  'booked_date': '2026-05-14',
  'value_date': null,
  'amount_minor': amountMinor,
  'currency': 'EUR',
  'description_raw': 'CB CARREFOUR MARKET 14/05',
  'description_clean': 'Carrefour Market',
  'merchant': merchant,
  'category': category,
  'categorization_source': categorizationSource,
  'categorization_confidence': null,
  'needs_review': needsReview,
  'fitid': null,
  'dedup_hash': 'hash-1',
  'created_at': '2026-05-14T00:00:00Z',
  'updated_at': '2026-05-14T00:00:00Z',
};

Map<String, dynamic> _categoryJson({
  String id = 'c1',
  String name = 'category.food.groceries',
}) => {
  'id': id,
  'user_id': null,
  'parent_id': null,
  'name': name,
  'kind': 'expense',
  'icon': 'shopping_cart',
  'color': '#10B981',
  'is_system': true,
};

Map<String, dynamic> _pageJson(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int total = 1,
}) => {'items': items, 'page': page, 'page_size': 50, 'total': total};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  test('build loads the first page with no filters', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _pageJson([_transactionJson()]));

    final page = await container.read(transactionsControllerProvider.future);

    expect(page.items, hasLength(1));
    expect(page.items.single.amountMinor, -1250);
    expect(page.total, 1);
  });

  test('changing filters re-fetches with the new query', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _pageJson([_transactionJson()]));

    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier).setNeedsReview(true);
    await container.read(transactionsControllerProvider.future);

    final captured = verify(
      () => apiClient.get('/transactions', query: captureAny(named: 'query')),
    ).captured;
    final lastQuery = captured.last as Map<String, String>;
    expect(lastQuery['needs_review'], 'true');
    expect(lastQuery['page'], '1');
  });

  test('setPage moves to the next page', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => _pageJson([_transactionJson()], page: 1, total: 120),
    );

    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier).setPage(2);
    await container.read(transactionsControllerProvider.future);

    final captured = verify(
      () => apiClient.get('/transactions', query: captureAny(named: 'query')),
    ).captured;
    expect((captured.last as Map<String, String>)['page'], '2');
  });

  test('updateCategory patches and clears the review flag in place', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => _pageJson([_transactionJson(id: 't1', needsReview: true)]),
    );
    when(
      () => apiClient.patch('/transactions/t1', body: any(named: 'body')),
    ).thenAnswer(
      (_) async => _transactionJson(
        id: 't1',
        needsReview: false,
        category: _categoryJson(),
        categorizationSource: 'user',
      ),
    );

    final page = await container.read(transactionsControllerProvider.future);
    await container
        .read(transactionsControllerProvider.notifier)
        .updateCategory(page.items.single, 'c1');

    final updated = container
        .read(transactionsControllerProvider)
        .value!
        .items
        .single;
    expect(updated.needsReview, isFalse);
    expect(updated.category?.id, 'c1');
    expect(updated.categorizationSource, CategorizationSource.user);
  });

  test('transactionCategoriesProvider maps the category catalog', () async {
    when(
      () => apiClient.get('/categories'),
    ).thenAnswer((_) async => [_categoryJson()]);

    final categories = await container.read(
      transactionCategoriesProvider.future,
    );

    expect(categories, hasLength(1));
    expect(categories.single.name, 'category.food.groceries');
  });

  test('TransactionsPage.totalPages rounds up', () {
    const page = TransactionsPage(items: [], page: 1, pageSize: 50, total: 120);
    expect(page.totalPages, 3);
  });
}
