import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/domain/networth_summary.dart';
import 'package:bastide/features/networth/presentation/declared_balances_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/networth_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _summaryJson(List<Map<String, dynamic>> series) => {
  'assets': {'accounts_minor': 0, 'properties_minor': 0},
  'liabilities': {'mortgages_minor': 0},
  'net_worth_minor': 0,
  'composition': <Map<String, dynamic>>[],
  'month_delta_minor': null,
  'series': series,
  'property_values_held_flat': false,
  'valued_on_oldest': null,
  'currency': 'EUR',
};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
    when(
      () => apiClient.get('/mortgages/summary'),
    ).thenAnswer((_) async => {'active_count': 0});
  });

  test('a declared point is told apart from an imported one', () async {
    when(() => apiClient.get('/networth/summary')).thenAnswer(
      (_) async => _summaryJson([
        {'month': '2025-03', 'net_worth_minor': 812345, 'source': 'declared'},
        {'month': '2026-04', 'net_worth_minor': 900000, 'source': 'ledger'},
      ]),
    );

    final summary = await container.read(networthControllerProvider.future);

    expect(summary.series.map((point) => point.declared), [true, false]);
    expect(summary.series.first.netWorthMinor, 812345);
    // A history alone is something to show: not the empty panel.
    expect(summary.isEmpty, isFalse);
  });

  test('the declared list maps exactly as returned', () async {
    when(() => apiClient.get('/networth/declared')).thenAnswer(
      (_) async => [
        {
          'month': '2025-03',
          'amount_minor': -15000,
          'currency': 'EUR',
          'superseded': true,
        },
      ],
    );

    final entries = await container.read(
      declaredBalancesControllerProvider.future,
    );

    expect(entries, hasLength(1));
    expect(entries.single.month, DateTime(2025, 3));
    expect(entries.single.amountMinor, -15000);
    expect(entries.single.superseded, isTrue);
  });

  test('a write puts the month key and re-reads list and summary', () async {
    var summaryReads = 0;
    when(() => apiClient.get('/networth/summary')).thenAnswer((_) async {
      summaryReads++;
      return _summaryJson([]);
    });
    when(
      () => apiClient.get('/networth/declared'),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(
      () => apiClient.put(
        '/networth/declared/2025-03',
        body: {'amount_minor': 812345},
      ),
    ).thenAnswer(
      (_) async => {
        'month': '2025-03',
        'amount_minor': 812345,
        'currency': 'EUR',
        'superseded': false,
      },
    );
    when(
      () => apiClient.delete('/networth/declared/2025-03'),
    ).thenAnswer((_) async => null);
    container.listen(networthControllerProvider, (_, _) {});
    await container.read(networthControllerProvider.future);
    await container.read(declaredBalancesControllerProvider.future);

    final notifier = container.read(
      declaredBalancesControllerProvider.notifier,
    );
    await notifier.declare(DateTime(2025, 3), 812345);
    await container.read(networthControllerProvider.future);
    await notifier.remove(DateTime(2025, 3));
    await container.read(networthControllerProvider.future);

    verify(
      () => apiClient.put(
        '/networth/declared/2025-03',
        body: {'amount_minor': 812345},
      ),
    ).called(1);
    verify(() => apiClient.delete('/networth/declared/2025-03')).called(1);
    verify(() => apiClient.get('/networth/declared')).called(3);
    expect(summaryReads, 3);
  });

  test('a refused write reaches the caller', () async {
    when(
      () => apiClient.get('/networth/declared'),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => apiClient.put(any(), body: any(named: 'body'))).thenThrow(
      const ApiFailure(code: 'DECLARED_MONTH_NOT_CLOSED', message: 'no'),
    );
    await container.read(declaredBalancesControllerProvider.future);

    expect(
      container
          .read(declaredBalancesControllerProvider.notifier)
          .declare(DateTime(2026, 5), 1),
      throwsA(isA<ApiFailure>()),
    );
  });

  group('pointsInRange', () {
    final series = longSeries();

    test('12 months and 3 years count back from the last month', () {
      final year = pointsInRange(series, NetworthRange.year);
      expect(year, hasLength(12));
      expect(year.first.month, DateTime(2025, 6));
      expect(year.last.month, DateTime(2026, 5));
      expect(pointsInRange(series, NetworthRange.threeYears), hasLength(30));
      expect(pointsInRange(series, NetworthRange.all), same(series));
    });

    test('a gap still counts as time passed', () {
      final sparse = [
        NetWorthPoint(month: DateTime(2024, 1), netWorthMinor: 1),
        NetWorthPoint(month: DateTime(2025, 5), netWorthMinor: 2),
        NetWorthPoint(month: DateTime(2026, 4), netWorthMinor: 3),
      ];

      expect(
        pointsInRange(sparse, NetworthRange.year).map((p) => p.netWorthMinor),
        [2, 3],
      );
    });

    test('an empty series stays empty', () {
      expect(pointsInRange(const [], NetworthRange.year), isEmpty);
    });
  });

  group('month input', () {
    test('reads MM/YYYY and M/YYYY, refuses anything else', () {
      expect(parseMonthInput('03/2025'), DateTime(2025, 3));
      expect(parseMonthInput(' 3 / 2025 '), DateTime(2025, 3));
      expect(parseMonthInput('13/2025'), isNull);
      expect(parseMonthInput('00/2025'), isNull);
      expect(parseMonthInput('2025-03'), isNull);
      expect(parseMonthInput(''), isNull);
    });

    test('round-trips through its formatter', () {
      expect(formatMonthInput(DateTime(2025, 3)), '03/2025');
      expect(
        parseMonthInput(formatMonthInput(DateTime(1999, 12))),
        DateTime(1999, 12),
      );
    });

    test('only an ended month is closed', () {
      final today = DateTime(2026, 5, 15);
      expect(isClosedMonth(DateTime(2026, 4), today), isTrue);
      expect(isClosedMonth(DateTime(2025, 12), today), isTrue);
      expect(isClosedMonth(DateTime(2026, 5), today), isFalse);
      expect(isClosedMonth(DateTime(2026, 6), today), isFalse);
    });
  });
}
