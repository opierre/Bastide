import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/dashboard/application/dashboard_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _summaryJson({
  int incomeMinor = 285000,
  int expenseMinor = 221435,
  int netMinor = 63565,
  double savingsRate = 0.223,
  double incomeDeltaPct = 2.1,
  double expenseDeltaPct = 4.8,
  double netDeltaPct = -6.1,
  double savingsRateDeltaPct = 1.9,
  List<Map<String, dynamic>> byCategory = const [],
}) => {
  'income_minor': incomeMinor,
  'expense_minor': expenseMinor,
  'net_minor': netMinor,
  'savings_rate': savingsRate,
  'income_delta_pct': incomeDeltaPct,
  'expense_delta_pct': expenseDeltaPct,
  'net_delta_pct': netDeltaPct,
  'savings_rate_delta_pct': savingsRateDeltaPct,
  'by_category': byCategory,
  'currency': 'EUR',
};

Map<String, dynamic> _transactionsPageJson(List<String> bookedDates) => {
  'items': [
    for (final date in bookedDates)
      {
        'id': 't-$date',
        'account_id': 'a1',
        'booked_date': date,
        'value_date': null,
        'amount_minor': -1000,
        'currency': 'EUR',
        'description_raw': 'TX',
        'description_clean': 'TX',
        'merchant': null,
        'category': null,
        'categorization_source': 'uncategorized',
        'categorization_confidence': null,
        'needs_review': true,
        'fitid': null,
        'dedup_hash': 'dedup-$date',
        'created_at':
            '$date'
            'T00:00:00Z',
        'updated_at':
            '$date'
            'T00:00:00Z',
      },
  ],
  'page': 1,
  'page_size': 50,
  'total': bookedDates.length,
};

Map<String, dynamic> _trendsJson() => {
  'monthly_series': [
    {
      'month': '2026-05',
      'income_minor': 285000,
      'expense_minor': 221435,
      'net_minor': 63565,
    },
  ],
  'savings_series': [
    {'month': '2026-04', 'cumulative_minor': 1020435},
    {'month': '2026-05', 'cumulative_minor': 1084000},
  ],
  'currency': 'EUR',
};

List<Map<String, dynamic>> _accountsJson() => [
  {
    'id': 'a1',
    'name': 'Compte courant',
    'type': 'checking',
    'institution': 'BNP',
    'currency': 'EUR',
    'opening_balance_minor': 0,
    'current_balance_minor': 0,
    'archived': false,
    'ofx_account_id': null,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  },
];

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  test(
    'build defaults to the month of the latest transaction and loads its summary',
    () async {
      when(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).thenAnswer(
        (_) async => _transactionsPageJson(['2026-05-14', '2026-04-02']),
      );
      when(
        () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
      ).thenAnswer((_) async => _summaryJson());
      when(
        () => apiClient.get('/dashboard/trends'),
      ).thenAnswer((_) async => _trendsJson());
      when(
        () => apiClient.get('/accounts'),
      ).thenAnswer((_) async => _accountsJson());

      final state = await container.read(dashboardControllerProvider.future);

      expect(state.month, DateTime(2026, 5));
      expect(state.summary.incomeMinor, 285000);
      verify(
        () => apiClient.get('/dashboard/summary', query: {'month': '2026-05'}),
      ).called(1);
    },
  );

  test(
    'build falls back to the current month when there are no transactions',
    () async {
      when(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).thenAnswer((_) async => _transactionsPageJson([]));
      when(
        () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
      ).thenAnswer((_) async => _summaryJson());
      when(
        () => apiClient.get('/dashboard/trends'),
      ).thenAnswer((_) async => _trendsJson());
      when(
        () => apiClient.get('/accounts'),
      ).thenAnswer((_) async => _accountsJson());

      final state = await container.read(dashboardControllerProvider.future);
      final now = DateTime.now();

      expect(state.month, DateTime(now.year, now.month));
    },
  );

  test('changeMonth re-fetches the summary for the new month', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _transactionsPageJson(['2026-05-14']));
    when(
      () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
    ).thenAnswer((_) async => _summaryJson());
    when(
      () => apiClient.get('/dashboard/trends'),
    ).thenAnswer((_) async => _trendsJson());
    when(
      () => apiClient.get('/accounts'),
    ).thenAnswer((_) async => _accountsJson());

    await container.read(dashboardControllerProvider.future);
    await container
        .read(dashboardControllerProvider.notifier)
        .changeMonth(DateTime(2026, 4));

    final state = container.read(dashboardControllerProvider).value!;
    expect(state.month, DateTime(2026, 4));
    verify(
      () => apiClient.get('/dashboard/summary', query: {'month': '2026-04'}),
    ).called(1);
  });

  test('the trend series survive a month change and are not re-fetched', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _transactionsPageJson(['2026-05-14']));
    when(
      () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
    ).thenAnswer((_) async => _summaryJson());
    when(
      () => apiClient.get('/dashboard/trends'),
    ).thenAnswer((_) async => _trendsJson());
    when(
      () => apiClient.get('/accounts'),
    ).thenAnswer((_) async => _accountsJson());

    await container.read(dashboardControllerProvider.future);
    await container
        .read(dashboardControllerProvider.notifier)
        .changeMonth(DateTime(2026, 1));

    final state = container.read(dashboardControllerProvider).value!;
    expect(state.month, DateTime(2026, 1));
    // Both windows end at the *current* month, so paging back to January leaves them alone —
    // and re-requesting a series that cannot have changed would be wasted work.
    expect(state.trends.totalSavedMinor, 1084000);
    verify(() => apiClient.get('/dashboard/trends')).called(1);
  });

  test('refresh does re-fetch the trends', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _transactionsPageJson(['2026-05-14']));
    when(
      () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
    ).thenAnswer((_) async => _summaryJson());
    when(
      () => apiClient.get('/dashboard/trends'),
    ).thenAnswer((_) async => _trendsJson());
    when(
      () => apiClient.get('/accounts'),
    ).thenAnswer((_) async => _accountsJson());

    await container.read(dashboardControllerProvider.future);
    await container.read(dashboardControllerProvider.notifier).refresh();

    verify(() => apiClient.get('/dashboard/trends')).called(2);
  });

  test('a failed month change surfaces as an AsyncError', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _transactionsPageJson(['2026-05-14']));
    when(
      () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
    ).thenAnswer((_) async => _summaryJson());
    when(
      () => apiClient.get('/dashboard/trends'),
    ).thenAnswer((_) async => _trendsJson());
    when(
      () => apiClient.get('/accounts'),
    ).thenAnswer((_) async => _accountsJson());

    await container.read(dashboardControllerProvider.future);

    when(
      () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
    ).thenThrow(
      const ApiFailure(code: 'DASHBOARD_MONTH_INVALID', message: 'bad month'),
    );
    await container
        .read(dashboardControllerProvider.notifier)
        .changeMonth(DateTime(2026, 13));

    final state = container.read(dashboardControllerProvider);
    expect(state.hasError, isTrue);
    expect((state.error as ApiFailure).code, 'DASHBOARD_MONTH_INVALID');
  });

  test('refresh reloads the currently selected month', () async {
    when(
      () => apiClient.get('/transactions', query: any(named: 'query')),
    ).thenAnswer((_) async => _transactionsPageJson(['2026-05-14']));
    when(
      () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
    ).thenAnswer((_) async => _summaryJson());
    when(
      () => apiClient.get('/dashboard/trends'),
    ).thenAnswer((_) async => _trendsJson());
    when(
      () => apiClient.get('/accounts'),
    ).thenAnswer((_) async => _accountsJson());

    await container.read(dashboardControllerProvider.future);
    await container.read(dashboardControllerProvider.notifier).refresh();

    verify(
      () => apiClient.get('/dashboard/summary', query: {'month': '2026-05'}),
    ).called(2);
  });
}
