import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/placements/application/placements_controller.dart';
import 'package:bastide/features/placements/domain/investment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _investmentJson({
  String id = 'i1',
  String envelope = 'pea',
  int? lastValueMinor = 3184000,
  String? closedOn,
}) => {
  'id': id,
  'name': 'PEA',
  'institution': 'Courtier Nord',
  'envelope': envelope,
  'opened_on': '2023-03-14',
  'closed_on': closedOn,
  'currency': 'EUR',
  'paid_in_minor': 2750000,
  'withdrawn_minor': -50000,
  'net_payments_minor': 2700000,
  'last_value_minor': lastValueMinor,
  'last_valued_on': lastValueMinor == null ? null : '2026-04-30',
  'unrealised_gain_minor': lastValueMinor == null ? null : 484000,
  'gain_bps': lastValueMinor == null ? null : 1793,
  'value_stale': false,
  'age_months': 38,
  'payment_ceiling_minor': 15000000,
  'milestone_years': 5,
  'milestone_on': '2028-03-14',
  'milestone_reached': false,
  'movement_count': 3,
  'linked_movement_count': 1,
  'created_at': '2023-03-14T00:00:00',
  'updated_at': '2026-04-30T00:00:00',
};

Map<String, dynamic> _summaryJson() => {
  'open_count': 1,
  'closed_count': 0,
  'declared_value_minor': 3184000,
  'net_payments_minor': 2700000,
  'unrealised_gain_minor': 484000,
  'gain_bps': 1793,
  'valued_count': 1,
  'stale_count': 0,
  'last_valued_on': '2026-04-30',
  'currency': 'EUR',
};

Map<String, dynamic> _detailJson() => {
  ..._investmentJson(),
  'movements': [
    {
      'id': 'm1',
      'investment_id': 'i1',
      'occurred_on': '2023-03-14',
      'amount_minor': 2750000,
      'currency': 'EUR',
      'note': 'Ouverture',
      'transaction_id': null,
      'created_at': '2023-03-14T00:00:00',
      'updated_at': '2023-03-14T00:00:00',
    },
    {
      'id': 'm2',
      'investment_id': 'i1',
      'occurred_on': '2026-04-30',
      'amount_minor': -50000,
      'currency': 'EUR',
      'note': null,
      'transaction_id': 't1',
      'created_at': '2026-04-30T00:00:00',
      'updated_at': '2026-04-30T00:00:00',
    },
  ],
  'valuations': [
    {
      'id': 'v1',
      'investment_id': 'i1',
      'valued_on': '2026-04-30',
      'value_minor': 3184000,
      'currency': 'EUR',
      'note': null,
      'created_at': '2026-04-30T00:00:00',
      'updated_at': '2026-04-30T00:00:00',
    },
  ],
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
      () => apiClient.get('/investments'),
    ).thenAnswer((_) async => [_investmentJson()]);
    when(
      () => apiClient.get('/investments/summary'),
    ).thenAnswer((_) async => _summaryJson());
  });

  test('loads the placements and the summary, money as minor units', () async {
    final state = await container.read(placementsControllerProvider.future);

    final investment = state.investments.single;
    expect(investment.envelope, Envelope.pea);
    expect(investment.netPaymentsMinor, 2700000);
    expect(investment.withdrawnMinor, -50000);
    expect(investment.unrealisedGainMinor, 484000);
    expect(investment.gainBps, 1793);
    expect(investment.milestoneOn, DateTime(2028, 3, 14));
    expect(investment.isClosed, isFalse);
    expect(state.summary.declaredValueMinor, 3184000);
    expect(state.summary.lastValuedOn, DateTime(2026, 4, 30));
    expect(state.selectedIn(null)?.id, 'i1');
    expect(state.selectedIn('gone')?.id, 'i1');
  });

  test('an envelope this build does not know reads as « Autre »', () async {
    when(
      () => apiClient.get('/investments'),
    ).thenAnswer((_) async => [_investmentJson(envelope: 'crypto')]);

    final state = await container.read(placementsControllerProvider.future);

    expect(state.investments.single.envelope, Envelope.other);
  });

  test(
    'the detail merges the history newest first, the value on top',
    () async {
      when(
        () => apiClient.get('/investments/i1'),
      ).thenAnswer((_) async => _detailJson());

      final detail = await container.read(placementDetailProvider('i1').future);

      expect(detail.history.map((entry) => entry.id), ['v1', 'm2', 'm1']);
      expect(detail.movements.last.isWithdrawal, isTrue);
      expect(detail.movements.last.transactionId, 't1');
    },
  );

  test('creating sends the opening history and selects the new one', () async {
    when(
      () => apiClient.post('/investments', body: any(named: 'body')),
    ).thenAnswer((_) async => _detailJson());
    await container.read(placementsControllerProvider.future);

    await container
        .read(placementsControllerProvider.notifier)
        .create(
          name: 'PEA',
          institution: 'Courtier Nord',
          envelope: Envelope.lifeInsurance,
          openedOn: DateTime(2023, 3, 14),
          initialPaymentsMinor: 2750000,
        );

    final body =
        verify(
              () => apiClient.post(
                '/investments',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body, {
      'name': 'PEA',
      'institution': 'Courtier Nord',
      'envelope': 'life_insurance',
      'opened_on': '2023-03-14',
      'initial_payments_minor': 2750000,
    });
    expect(container.read(selectedPlacementProvider), 'i1');
    verify(() => apiClient.get('/investments')).called(2);
  });

  test('a movement is sent signed; editing clears a dropped note', () async {
    when(
      () => apiClient.post(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(
      () => apiClient.patch(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => <String, dynamic>{});
    await container.read(placementsControllerProvider.future);
    final controller = container.read(placementsControllerProvider.notifier);

    await controller.addMovement(
      'i1',
      occurredOn: DateTime(2026, 5, 2),
      amountMinor: -30000,
    );
    await controller.updateMovement(
      'i1',
      'm1',
      occurredOn: DateTime(2026, 5, 2),
      amountMinor: 30000,
    );

    expect(
      verify(
        () => apiClient.post(
          '/investments/i1/movements',
          body: captureAny(named: 'body'),
        ),
      ).captured.single,
      {'occurred_on': '2026-05-02', 'amount_minor': -30000},
    );
    expect(
      verify(
        () => apiClient.patch(
          '/investments/i1/movements/m1',
          body: captureAny(named: 'body'),
        ),
      ).captured.single,
      {
        'occurred_on': '2026-05-02',
        'amount_minor': 30000,
        'note': null,
        'transaction_id': null,
      },
    );
  });

  test('a form write rethrows the API failure for the form to show', () async {
    when(() => apiClient.post(any(), body: any(named: 'body'))).thenThrow(
      const ApiFailure(code: 'INVESTMENT_VALUATION_EXISTS', message: 'taken'),
    );
    await container.read(placementsControllerProvider.future);

    await expectLater(
      container
          .read(placementsControllerProvider.notifier)
          .addValuation(
            'i1',
            valuedOn: DateTime(2026, 4, 30),
            valueMinor: 3200000,
          ),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('a refused delete keeps the table and reports in the banner', () async {
    when(() => apiClient.delete('/investments/i1')).thenThrow(
      const ApiFailure(code: 'INVESTMENT_NOT_FOUND', message: 'gone'),
    );
    await container.read(placementsControllerProvider.future);

    await container.read(placementsControllerProvider.notifier).delete('i1');

    final state = container.read(placementsControllerProvider).value!;
    expect(state.investments, hasLength(1));
    expect((state.actionError! as ApiFailure).code, 'INVESTMENT_NOT_FOUND');
  });

  test('the stale list leaves closed placements out', () async {
    when(() => apiClient.get('/investments')).thenAnswer(
      (_) async => [
        {..._investmentJson(), 'value_stale': true},
        {
          ..._investmentJson(id: 'i2', closedOn: '2026-01-01'),
          'value_stale': true,
        },
      ],
    );

    final state = await container.read(placementsControllerProvider.future);

    expect(state.stale.map((i) => i.id), ['i1']);
  });
}
