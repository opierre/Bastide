import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/accounts/application/account_detail_controller.dart';
import 'package:bastide/features/accounts/domain/account_overview.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'account_overview_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _transactionJson(int i) => {
  'id': 't$i',
  'account_id': 'acc-1',
  'booked_date': '2026-10-${(29 - i).toString().padLeft(2, '0')}',
  'value_date': null,
  'amount_minor': -1000 - i,
  'currency': 'EUR',
  'description_raw': 'ACHAT $i',
  'description_clean': 'Achat $i',
  'memo': null,
  'merchant': null,
  'category': null,
  'categorization_source': 'uncategorized',
  'categorization_confidence': null,
  'needs_review': true,
  'fitid': null,
  'dedup_hash': 'h$i',
  'created_at': '2026-10-30T00:00:00Z',
  'updated_at': '2026-10-30T00:00:00Z',
};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUp(() {
    apiClient = MockApiClient();
    when(
      () => apiClient.get('/accounts'),
    ).thenAnswer((_) async => [accountJson()]);
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  test('the overview is read from the account overview endpoint', () async {
    when(
      () => apiClient.get('/accounts/acc-1/overview'),
    ).thenAnswer((_) async => checkingOverviewJson());

    final sub = container.listen(accountOverviewProvider('acc-1'), (_, _) {});
    addTearDown(sub.close);
    final overview = await container.read(
      accountOverviewProvider('acc-1').future,
    );

    expect(overview.account.id, 'acc-1');
    expect(overview.linkedCards, hasLength(2));
  });

  test('recent transactions are the account\'s first eight', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => {
        'items': [for (var i = 0; i < 12; i++) _transactionJson(i)],
        'page': 1,
        'page_size': 50,
        'total': 12,
      },
    );

    final sub = container.listen(
      recentAccountTransactionsProvider('acc-1'),
      (_, _) {},
    );
    addTearDown(sub.close);
    final recent = await container.read(
      recentAccountTransactionsProvider('acc-1').future,
    );

    expect(recent, hasLength(recentTransactionCount));
    expect(recent.first.id, 't0');
    final query =
        verify(
              () => apiClient.get(
                '/transactions',
                query: captureAny(named: 'query'),
              ),
            ).captured.single
            as Map<String, String>;
    expect(query['account_id'], 'acc-1');
  });

  test('recent transactions are re-read after a category edit', () async {
    var category = 'uncategorized';
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => {
        'items': [
          {..._transactionJson(0), 'categorization_source': category},
        ],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
    );
    final sub = container.listen(
      recentAccountTransactionsProvider('acc-1'),
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(recentAccountTransactionsProvider('acc-1').future);

    category = 'user';
    container.read(transactionEditsProvider.notifier).saved();
    final recent = await container.read(
      recentAccountTransactionsProvider('acc-1').future,
    );

    expect(recent.single.categorizationSource, CategorizationSource.user);
    verify(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).called(2);
  });

  test('the chart opens on twelve months and follows the range', () async {
    // Twenty month-ends, January 2025 onward.
    final history = [
      for (var month = 1; month <= 20; month++)
        {
          'as_of': DateTime(
            2025,
            month + 1,
            0,
          ).toIso8601String().substring(0, 10),
          'balance_minor': month * 1000,
        },
    ];
    when(() => apiClient.get('/accounts/acc-1/overview')).thenAnswer(
      (_) async => {...checkingOverviewJson(), 'balance_history': history},
    );
    final sub = container.listen(
      visibleBalanceHistoryProvider('acc-1'),
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(accountOverviewProvider('acc-1').future);

    expect(
      container.read(balanceRangeControllerProvider('acc-1')),
      BalanceRange.twelveMonths,
    );
    expect(sub.read(), hasLength(12));
    expect(sub.read().last.balanceMinor, 20000);

    container
        .read(balanceRangeControllerProvider('acc-1').notifier)
        .select(BalanceRange.sixMonths);
    expect(sub.read(), hasLength(6));

    container
        .read(balanceRangeControllerProvider('acc-1').notifier)
        .select(BalanceRange.all);
    expect(sub.read(), hasLength(20));
  });

  test('an account is looked up in the accounts list by id', () async {
    final sub = container.listen(accountByIdProvider('acc-1'), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read()?.name, 'Compte courant');
    expect(container.read(accountByIdProvider(null)), isNull);
    expect(container.read(accountByIdProvider('missing')), isNull);
  });
}
