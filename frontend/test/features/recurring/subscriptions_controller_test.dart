import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/recurring_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/recurring_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _seriesJson({
  String id = 's1',
  String label = 'Netflix',
  String cadence = 'monthly',
  int expectedAmountMinor = -1549,
  String status = 'detected',
  String? categoryId,
  int? priceChangeMinor,
  String? priceChangedAt,
}) => {
  'id': id,
  'account_id': 'a1',
  'label': label,
  'category_id': categoryId,
  'cadence': cadence,
  'median_interval_days': 30,
  'expected_amount_minor': expectedAmountMinor,
  'currency': 'EUR',
  'first_seen_date': '2025-12-15',
  'last_seen_date': '2026-04-15',
  'next_expected_date': '2026-05-15',
  'occurrence_count': 5,
  'status': status,
  'is_manual': false,
  'price_change_minor': priceChangeMinor,
  'price_changed_at': priceChangedAt,
  'created_at': '2026-01-01T00:00:00',
  'updated_at': '2026-05-01T00:00:00',
};

Map<String, dynamic> _summaryJson({
  int monthlyTotalMinor = -21208,
  int activeCount = 1,
  int cancelledCount = 0,
  List<Map<String, dynamic>> priceIncreases = const [],
  List<Map<String, dynamic>> missed = const [],
}) => {
  'monthly_total_minor': monthlyTotalMinor,
  'active_count': activeCount,
  'cancelled_count': cancelledCount,
  'cadence_counts': {
    'weekly': 0,
    'monthly': activeCount,
    'quarterly': 0,
    'yearly': 0,
    'irregular': 0,
  },
  'next_charge': {
    'series_id': 's1',
    'label': 'Netflix',
    'amount_minor': -1549,
    'due_on': '2026-05-15',
  },
  'price_increases': priceIncreases,
  'missed': missed,
  'currency': 'EUR',
};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  void stubLoad({
    List<Map<String, dynamic>>? series,
    Map<String, dynamic>? summary,
  }) {
    when(
      () => apiClient.get('/recurring', query: any(named: 'query')),
    ).thenAnswer((_) async => series ?? [_seriesJson()]);
    when(
      () => apiClient.get('/recurring/summary'),
    ).thenAnswer((_) async => summary ?? _summaryJson());
  }

  test('build loads the series and the summary together', () async {
    stubLoad();

    final state = await container.read(subscriptionsControllerProvider.future);

    expect(state.series, hasLength(1));
    expect(state.series.first.label, 'Netflix');
    expect(state.series.first.cadence, Cadence.monthly);
    expect(state.summary.monthlyTotalMinor, -21208);
    expect(state.summary.nextCharge?.label, 'Netflix');
    expect(state.statusFilter, isNull);
  });

  test('the summary signals are joined onto the rows they belong to', () async {
    stubLoad(
      series: [
        _seriesJson(),
        _seriesJson(id: 's2', label: 'Basic-Fit', expectedAmountMinor: -2999),
        _seriesJson(id: 's3', label: 'Spotify', expectedAmountMinor: -1799),
      ],
      summary: _summaryJson(
        activeCount: 3,
        priceIncreases: [
          {'series_id': 's1', 'delta_minor': -200, 'changed_at': '2026-04-15'},
        ],
        missed: [
          {'series_id': 's2', 'expected_on': '2026-05-05', 'days_late': 9},
        ],
      ),
    );

    final state = await container.read(subscriptionsControllerProvider.future);

    final increase = state.rows.first.signal;
    expect(increase, isA<PriceIncreaseSignal>());
    increase as PriceIncreaseSignal;
    expect(increase.previousAmountMinor, -1349);
    expect(increase.currentAmountMinor, -1549);

    expect(state.rows[1].signal, isA<MissedChargeSignal>());
    expect((state.rows[1].signal! as MissedChargeSignal).daysLate, 9);

    // A healthy subscription carries no signal at all — the Statut cell it
    // renders is empty, not an "OK".
    expect(state.rows[2].signal, isNull);
  });

  test(
    'a cancelled row reports its last charge, not a summary signal',
    () async {
      stubLoad(series: [_seriesJson(status: 'cancelled')]);

      final state = await container.read(
        subscriptionsControllerProvider.future,
      );

      expect(state.rows.single.signal, isA<CancelledSignal>());
      expect(
        (state.rows.single.signal! as CancelledSignal).lastChargeOn,
        DateTime(2026, 4, 15),
      );
    },
  );

  test('setStatusFilter re-lists under that status', () async {
    stubLoad();
    await container.read(subscriptionsControllerProvider.future);

    await container
        .read(subscriptionsControllerProvider.notifier)
        .setStatusFilter(SeriesStatus.confirmed);

    final captured = verify(
      () => apiClient.get('/recurring', query: captureAny(named: 'query')),
    ).captured;
    expect(captured.last, {'status': 'confirmed'});
    expect(
      container.read(subscriptionsControllerProvider).value?.statusFilter,
      SeriesStatus.confirmed,
    );
  });

  test('a transition patch updates the row in place', () async {
    stubLoad();
    when(
      () => apiClient.patch('/recurring/s1', body: any(named: 'body')),
    ).thenAnswer((_) async => _seriesJson(status: 'confirmed'));
    await container.read(subscriptionsControllerProvider.future);

    await container
        .read(subscriptionsControllerProvider.notifier)
        .changeStatus('s1', SeriesStatus.confirmed);

    final state = container.read(subscriptionsControllerProvider).value!;
    expect(state.series.single.status, SeriesStatus.confirmed);
    expect(state.actionError, isNull);
    verify(
      () => apiClient.patch('/recurring/s1', body: {'status': 'confirmed'}),
    ).called(1);
  });

  test(
    'a 409 surfaces as an error on the state without losing the list',
    () async {
      stubLoad();
      when(
        () => apiClient.patch('/recurring/s1', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(
          code: 'RECURRING_INVALID_TRANSITION',
          message: 'That status change is not allowed for this series.',
        ),
      );
      await container.read(subscriptionsControllerProvider.future);

      await container
          .read(subscriptionsControllerProvider.notifier)
          .changeStatus('s1', SeriesStatus.confirmed);

      final state = container.read(subscriptionsControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value!.series, hasLength(1));
      expect(state.value!.series.single.status, SeriesStatus.detected);
      expect(
        (state.value!.actionError! as ApiFailure).code,
        'RECURRING_INVALID_TRANSITION',
      );
    },
  );

  test('a row that leaves the active filter drops out of the list', () async {
    stubLoad();
    when(
      () => apiClient.patch('/recurring/s1', body: any(named: 'body')),
    ).thenAnswer((_) async => _seriesJson(status: 'dismissed'));
    await container.read(subscriptionsControllerProvider.future);
    await container
        .read(subscriptionsControllerProvider.notifier)
        .setStatusFilter(SeriesStatus.detected);

    await container
        .read(subscriptionsControllerProvider.notifier)
        .changeStatus('s1', SeriesStatus.dismissed);

    expect(
      container.read(subscriptionsControllerProvider).value!.series,
      isEmpty,
    );
  });

  test('detect runs a pass and reloads the panel behind it', () async {
    stubLoad();
    when(
      () => apiClient.post('/recurring/detect', body: any(named: 'body')),
    ).thenAnswer((_) async => {'created_count': 2, 'updated_count': 1});
    await container.read(subscriptionsControllerProvider.future);

    final result = await container
        .read(subscriptionsControllerProvider.notifier)
        .detect();

    expect(result.createdCount, 2);
    expect(result.updatedCount, 1);
    verify(
      () => apiClient.get('/recurring', query: any(named: 'query')),
    ).called(2);
    verify(() => apiClient.get('/recurring/summary')).called(2);
  });

  test('creating a manual series reloads the list', () async {
    stubLoad();
    when(
      () => apiClient.post('/recurring', body: any(named: 'body')),
    ).thenAnswer(
      (_) async =>
          _seriesJson(id: 's9', label: 'Basic-Fit', expectedAmountMinor: -2999),
    );
    await container.read(subscriptionsControllerProvider.future);

    final created = await container
        .read(subscriptionsControllerProvider.notifier)
        .create(
          label: 'Basic-Fit',
          accountId: 'a1',
          expectedAmountMinor: -2999,
          cadence: Cadence.irregular,
        );

    expect(created.id, 's9');
    verify(
      () => apiClient.post(
        '/recurring',
        body: {
          'label': 'Basic-Fit',
          'account_id': 'a1',
          'expected_amount_minor': -2999,
          'cadence': 'irregular',
        },
      ),
    ).called(1);
  });

  group('annualised impact of a price change', () {
    // A 2,00 € rise on an outflow is a −200 step; over a year it is that step
    // times the number of charges the cadence produces.
    const step = -200;

    test('weekly multiplies by 52', () {
      expect(
        testSeries(
          cadence: Cadence.weekly,
          priceChangeMinor: step,
        ).annualPriceImpactMinor,
        -10400,
      );
    });

    test('monthly multiplies by 12', () {
      expect(
        testSeries(
          cadence: Cadence.monthly,
          priceChangeMinor: step,
        ).annualPriceImpactMinor,
        -2400,
      );
    });

    test('quarterly multiplies by 4', () {
      expect(
        testSeries(
          cadence: Cadence.quarterly,
          priceChangeMinor: step,
        ).annualPriceImpactMinor,
        -800,
      );
    });

    test('yearly is the step itself', () {
      expect(
        testSeries(
          cadence: Cadence.yearly,
          priceChangeMinor: step,
        ).annualPriceImpactMinor,
        step,
      );
    });

    test('irregular has none — there is no year to spread it over', () {
      expect(
        testSeries(
          cadence: Cadence.irregular,
          priceChangeMinor: step,
        ).annualPriceImpactMinor,
        isNull,
      );
    });

    test('a series with no recorded change has no impact to state', () {
      expect(testSeries().annualPriceImpactMinor, isNull);
    });
  });
}
