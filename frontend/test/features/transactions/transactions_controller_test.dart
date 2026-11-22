import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:bastide/features/transactions/application/transaction_selection.dart';
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
  'color': 'cat3',
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

  test('maps the series a transaction belongs to, or none', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => _pageJson([
        {..._transactionJson(id: 't1'), 'recurring_series_id': 's9'},
        {..._transactionJson(id: 't2'), 'recurring_series_id': null},
      ], total: 2),
    );

    final page = await container.read(transactionsControllerProvider.future);

    expect(page.items.map((t) => t.recurringSeriesId), ['s9', null]);
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

  test('an import filter asks for that import\'s rows only', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _pageJson([_transactionJson()]));

    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier)
      ..setCategory('c1')
      ..setQuery('loyer')
      ..showImport(
        const ImportBatchFilter(id: 'b1', fileName: 'releve.ofx'),
        accountId: 'a1',
      );
    await container.read(transactionsControllerProvider.future);

    final captured = verify(
      () => apiClient.get('/transactions', query: captureAny(named: 'query')),
    ).captured;
    final lastQuery = captured.last as Map<String, String>;
    expect(lastQuery['import_batch_id'], 'b1');
    expect(lastQuery['account_id'], 'a1');
    // Leftover filters would hide some of the import's rows.
    expect(lastQuery.containsKey('category_id'), isFalse);
    expect(lastQuery.containsKey('q'), isFalse);
  });

  test('clearing the import filter drops it from the query', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _pageJson([_transactionJson()]));

    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier)
      ..showImport(
        const ImportBatchFilter(id: 'b1', fileName: 'releve.ofx'),
        accountId: 'a1',
      )
      ..clearImport();
    await container.read(transactionsControllerProvider.future);

    final captured = verify(
      () => apiClient.get('/transactions', query: captureAny(named: 'query')),
    ).captured;
    final lastQuery = captured.last as Map<String, String>;
    expect(lastQuery.containsKey('import_batch_id'), isFalse);
    expect(lastQuery['account_id'], 'a1');
  });

  test('picking another account drops the import filter', () {
    final notifier = container.read(transactionFiltersProvider.notifier)
      ..showImport(
        const ImportBatchFilter(id: 'b1', fileName: 'releve.ofx'),
        accountId: 'a1',
      );

    notifier.setAccount('a1');
    expect(container.read(transactionFiltersProvider).importBatch, isNotNull);

    notifier.setAccount('a2');
    expect(container.read(transactionFiltersProvider).importBatch, isNull);
  });

  test('an account filter takes in the account\'s linked cards', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _pageJson([_transactionJson()]));

    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier).setAccount('a1');
    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier).setNeedsReview(true);
    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier)
      ..setNeedsReview(null)
      ..setAccount(null);
    await container.read(transactionsControllerProvider.future);

    final queries = verify(
      () => apiClient.get('/transactions', query: captureAny(named: 'query')),
    ).captured.cast<Map<String, String>>();
    expect(queries, hasLength(4));
    // Unfiltered: no account, nothing to widen.
    expect(queries[0].containsKey('include_linked_cards'), isFalse);
    // Filtered: the account and the deferred cards it settles.
    expect(queries[1]['account_id'], 'a1');
    expect(queries[1]['include_linked_cards'], 'true');
    // The « À vérifier » tab is the whole queue: the account picked on
    // « Toutes » does not narrow it unseen.
    expect(queries[2].containsKey('account_id'), isFalse);
    expect(queries[2]['needs_review'], 'true');
    expect(queries[2].containsKey('include_linked_cards'), isFalse);
    // Back to all accounts: the flag goes with the filter.
    expect(queries[3].containsKey('account_id'), isFalse);
    expect(queries[3].containsKey('include_linked_cards'), isFalse);
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

  test('the page carries the net', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => {
        ..._pageJson([_transactionJson()]),
        'net_minor': -48_210,
      },
    );

    final page = await container.read(transactionsControllerProvider.future);

    expect(page.netMinor, -48_210);
  });

  test('the review tab reads the queue with the search only', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _pageJson([_transactionJson()]));

    container.read(transactionFiltersProvider.notifier)
      ..setAccount('a1')
      ..setCategory('c1')
      ..setDateRange(DateTime(2026, 5, 1), DateTime(2026, 5, 31))
      ..setQuery('cafe')
      ..setNeedsReview(true);
    await container.read(transactionsControllerProvider.future);

    final query =
        verify(
              () => apiClient.get(
                '/transactions',
                query: captureAny(named: 'query'),
              ),
            ).captured.last
            as Map<String, String>;
    expect(query, {'page': '1', 'needs_review': 'true', 'q': 'cafe'});
    // Kept for the way back to « Toutes ».
    final filters = container.read(transactionFiltersProvider);
    expect(filters.accountId, 'a1');
    expect(filters.categoryId, 'c1');
  });

  test('an operation filter reads that operation alone', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _pageJson([_transactionJson()]));
    when(
      () => apiClient.get('/transactions/t9'),
    ).thenAnswer((_) async => _transactionJson(id: 't9', amountMinor: -4210));

    await container.read(transactionsControllerProvider.future);
    container.read(transactionFiltersProvider.notifier)
      ..setCategory('c1')
      ..setQuery('loyer')
      ..showOperation('t9');
    final page = await container.read(transactionsControllerProvider.future);

    expect(page.items.map((t) => t.id), ['t9']);
    expect(page.total, 1);
    expect(page.netMinor, -4210);
    // Nothing else narrows it, so nothing hides it.
    expect(
      container.read(transactionFiltersProvider),
      const TransactionFilters(operationId: 't9'),
    );
  });

  test('any other filter lifts the operation filter', () {
    final notifier = container.read(transactionFiltersProvider.notifier);
    final lifts = <void Function()>[
      () => notifier.setAccount('a1'),
      () => notifier.setDateRange(DateTime(2026, 5), DateTime(2026, 5, 31)),
      () => notifier.setCategory('c1'),
      () => notifier.setQuery('cafe'),
      notifier.clearOperation,
      notifier.clearFilters,
    ];
    for (final lift in lifts) {
      notifier.showOperation('t9');
      lift();
      expect(container.read(transactionFiltersProvider).operationId, isNull);
    }
  });

  test('the operation filter survives a trip to « À vérifier »', () {
    container.read(transactionFiltersProvider.notifier)
      ..showOperation('t9')
      ..setNeedsReview(true)
      ..setNeedsReview(null);

    expect(container.read(transactionFiltersProvider).operationId, 't9');
    expect(container.read(transactionFiltersProvider).hasListFilter, isTrue);
  });

  test('clearFilters lifts every filter and stays on the tab', () {
    final notifier = container.read(transactionFiltersProvider.notifier)
      ..setAccount('a1')
      ..setQuery('cafe')
      ..setPage(3);

    notifier.clearFilters();

    expect(
      container.read(transactionFiltersProvider),
      const TransactionFilters(),
    );
    expect(container.read(transactionFiltersProvider).hasListFilter, isFalse);
  });

  test('the context maps the import, rule, series and history', () async {
    when(() => apiClient.get('/transactions/t1/context')).thenAnswer(
      (_) async => {
        'import_batch_id': 'b1',
        'import_file_name': 'releve-mai.ofx',
        'rule': {
          'id': 'r1',
          'match_field': 'description_clean',
          'match_type': 'contains',
          'pattern': 'ASSUR',
        },
        'series': {
          'id': 's1',
          'cadence': 'yearly',
          'next_expected_date': '2026-11-21',
        },
        'same_merchant': [
          {
            'id': 't0',
            'booked_date': '2025-11-21',
            'amount_minor': -17_990,
            'currency': 'EUR',
          },
        ],
      },
    );

    final details = await container.read(
      transactionContextProvider('t1').future,
    );

    expect(details.importFileName, 'releve-mai.ofx');
    expect(details.rule?.pattern, 'ASSUR');
    expect(details.series?.cadence, 'yearly');
    expect(details.series?.nextExpectedDate, DateTime(2026, 11, 21));
    expect(details.sameMerchant.single.amountMinor, -17_990);
  });

  group('selection', () {
    final items = [
      for (final id in ['t1', 't2', 't3']) _tx(id),
    ];

    test('↓ with nothing selected lands on the first row', () {
      container.read(selectedTransactionProvider.notifier).move(items, 1);
      expect(container.read(selectedTransactionProvider), 't1');
    });

    test('↑ with nothing selected lands on the last row', () {
      container.read(selectedTransactionProvider.notifier).move(items, -1);
      expect(container.read(selectedTransactionProvider), 't3');
    });

    test('moves stop at either end', () {
      final selection = container.read(selectedTransactionProvider.notifier)
        ..select('t2')
        ..move(items, 1)
        ..move(items, 1);
      expect(container.read(selectedTransactionProvider), 't3');
      selection
        ..move(items, -1)
        ..move(items, -1)
        ..move(items, -1);
      expect(container.read(selectedTransactionProvider), 't1');
    });
  });

  test('groupByDay keeps the page order and splits it by day', () {
    Transaction on(String id, DateTime date) => _tx(id, date);
    final days = groupByDay([
      on('a', DateTime(2026, 5, 14)),
      on('b', DateTime(2026, 5, 14)),
      on('c', DateTime(2026, 5, 12)),
    ]);

    expect(days.map((day) => day.date), [
      DateTime(2026, 5, 14),
      DateTime(2026, 5, 12),
    ]);
    expect(days.first.items.map((item) => item.id), ['a', 'b']);
  });

  test('pickerOrder lists each category followed by its subcategories', () {
    AppCategory category(String id, {String? parent}) => AppCategory(
      id: id,
      userId: null,
      parentId: parent,
      name: id,
      kind: 'expense',
      icon: 'tag',
      color: 'cat1',
      isSystem: false,
    );
    final order = pickerOrder([
      category('home'),
      category('food'),
      category('rent', parent: 'home'),
      category('cafe', parent: 'food'),
    ]);

    expect(order.map((entry) => (entry.sub ?? entry.top).id), [
      'home',
      'rent',
      'food',
      'cafe',
    ]);
    expect(order[1].top.id, 'home');
  });
}

Transaction _tx(String id, [DateTime? bookedDate]) => Transaction(
  id: id,
  accountId: 'a1',
  bookedDate: bookedDate ?? DateTime(2026, 5, 14),
  valueDate: null,
  amountMinor: -1250,
  currency: 'EUR',
  descriptionRaw: 'CB CARREFOUR MARKET 14/05',
  descriptionClean: 'Carrefour Market',
  memo: null,
  merchant: 'Carrefour',
  category: null,
  categorizationSource: CategorizationSource.rule,
  categorizationConfidence: null,
  needsReview: false,
  fitid: null,
  dedupHash: 'hash-$id',
  createdAt: DateTime.utc(2026, 5, 14),
  updatedAt: DateTime.utc(2026, 5, 14),
);
