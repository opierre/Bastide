import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/simulator/application/simulator_controller.dart';
import 'package:bastide/features/simulator/data/simulations_repository.dart';
import 'package:bastide/features/simulator/domain/simulation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/simulator_fixtures.dart';

class MockSimulationsRepository extends Mock implements SimulationsRepository {}

class MockApiClient extends Mock implements ApiClient {}

/// Lets the debounce elapse and the answer land.
Future<void> _settle() => Future<void>.delayed(
  SimulatorController.debounce + const Duration(milliseconds: 60),
);

void main() {
  setUpAll(() {
    registerFallbackValue(testTerms);
    registerFallbackValue(<String, dynamic>{});
  });

  group('controller', () {
    late MockSimulationsRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockSimulationsRepository();
      when(
        () => repository.household(),
      ).thenAnswer((_) async => testHousehold());
      when(() => repository.list()).thenAnswer((_) async => []);
      when(
        () => repository.compute(
          any(),
          includeExistingLoans: any(named: 'includeExistingLoans'),
        ),
      ).thenAnswer((_) async => testResult());
      container = ProviderContainer(
        overrides: [
          simulationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
    });

    SimulatorController notifier() =>
        container.read(simulatorControllerProvider.notifier);

    SimulatorState current() =>
        container.read(simulatorControllerProvider).value!;

    /// Types the frame's simulation into the form.
    void typeFrameInputs() {
      notifier()
        ..setPropertyPrice(32000000)
        ..setDownPayment(4000000)
        ..setFees(450000)
        ..setRate(325)
        ..setInsurance(3200);
    }

    test('build loads the household and the saved scenarios', () async {
      when(() => repository.list()).thenAnswer((_) async => [testScenario()]);

      final state = await container.read(simulatorControllerProvider.future);

      expect(state.household.existingChargeMinor, 150625);
      expect(state.scenarios.single.label, 'Villeurbanne — 265 k€');
      expect(state.result, isNull);
      expect(state.inputs.termMonths, 300);
      await _settle();
      expect(current().scenarioInstalments, {'s1': 141841});
    });

    test('computes once after the debounce, never saving anything', () async {
      await container.read(simulatorControllerProvider.future);

      typeFrameInputs();
      notifier().setRate(330);
      notifier().setRate(325);

      verifyNever(
        () => repository.compute(
          any(),
          includeExistingLoans: any(named: 'includeExistingLoans'),
        ),
      );
      expect(current().computing, isTrue);

      await _settle();

      final captured = verify(
        () => repository.compute(captureAny(), includeExistingLoans: false),
      ).captured;
      expect(captured, [testTerms]);
      expect(current().result?.totalInstalmentMinor, 141841);
      expect(current().computing, isFalse);
      verifyNever(() => repository.create(any(), any()));
    });

    test(
      'nothing is computed until a borrowed amount and a rate exist',
      () async {
        await container.read(simulatorControllerProvider.future);

        notifier().setPropertyPrice(32000000);
        await _settle();

        expect(current().canCompute, isFalse);
        expect(current().result, isNull);
        verifyNever(
          () => repository.compute(
            any(),
            includeExistingLoans: any(named: 'includeExistingLoans'),
          ),
        );
      },
    );

    group('borrowed amount', () {
      test('defaults to price + fees − down payment', () async {
        await container.read(simulatorControllerProvider.future);

        typeFrameInputs();

        expect(current().inputs.principalMinor, 28450000);
        expect(current().principalDerived, isTrue);
      });

      test(
        'stops deriving once edited, until price or down payment change',
        () async {
          await container.read(simulatorControllerProvider.future);
          typeFrameInputs();

          notifier().setPrincipal(25000000);
          notifier().setFees(500000);
          expect(current().inputs.principalMinor, 25000000);
          expect(current().principalDerived, isFalse);

          notifier().setDownPayment(5000000);
          expect(current().principalDerived, isTrue);
          expect(current().inputs.principalMinor, 27500000);
        },
      );

      test(
        'is absent without a price or when the down payment covers it',
        () async {
          await container.read(simulatorControllerProvider.future);

          notifier().setDownPayment(1000);
          expect(current().inputs.principalMinor, isNull);

          notifier().setPropertyPrice(500);
          expect(current().inputs.principalMinor, isNull);
        },
      );
    });

    test('a refused loan is kept as a compute error, not a result', () async {
      await container.read(simulatorControllerProvider.future);
      when(
        () => repository.compute(
          any(),
          includeExistingLoans: any(named: 'includeExistingLoans'),
        ),
      ).thenThrow(
        const ApiFailure(code: 'MORTGAGE_NON_AMORTIZING', message: 'no'),
      );

      typeFrameInputs();
      await _settle();

      expect(current().result, isNull);
      expect(
        (current().computeError as ApiFailure).code,
        'MORTGAGE_NON_AMORTIZING',
      );
      expect(current().canSave, isFalse);
    });

    test('the existing-loans switch recomputes with them included', () async {
      await container.read(simulatorControllerProvider.future);
      typeFrameInputs();
      await _settle();

      notifier().setIncludeExistingLoans(true);
      await _settle();

      verify(
        () => repository.compute(testTerms, includeExistingLoans: true),
      ).called(1);
    });

    group('unknown income', () {
      test('maps to an absent ratio and capacity, never zero', () async {
        when(
          () => repository.compute(
            any(),
            includeExistingLoans: any(named: 'includeExistingLoans'),
          ),
        ).thenAnswer((_) async => testUnknownIncomeResult());
        await container.read(simulatorControllerProvider.future);

        typeFrameInputs();
        await _settle();

        final state = current();
        expect(state.incomeKnown, isFalse);
        expect(state.result!.debtRatioBps, isNull);
        expect(state.result!.maxBorrowableMinor, isNull);
        expect(state.result!.hcsf.withinRatio, isNull);
      });

      test(
        'an over-reference reading still computes and can be saved',
        () async {
          when(
            () => repository.compute(
              any(),
              includeExistingLoans: any(named: 'includeExistingLoans'),
            ),
          ).thenAnswer((_) async => testOverLimitResult());
          await container.read(simulatorControllerProvider.future);

          typeFrameInputs();
          await _settle();

          expect(current().incomeKnown, isTrue);
          expect(current().result!.hcsf.withinRatio, isFalse);
          expect(current().canSave, isTrue);
        },
      );
    });

    group('scenarios', () {
      test('save sends the current inputs and appends the row', () async {
        when(
          () => repository.create(any(), any()),
        ).thenAnswer((_) async => testScenario(id: 's9', label: 'Lyon 3e'));
        await container.read(simulatorControllerProvider.future);
        typeFrameInputs();
        await _settle();

        await notifier().saveScenario('Lyon 3e');

        verify(() => repository.create('Lyon 3e', testTerms)).called(1);
        expect(current().scenarios.map((s) => s.id), ['s9']);
      });

      test('save is refused without a price', () async {
        await container.read(simulatorControllerProvider.future);
        notifier()
          ..setPrincipal(20000000)
          ..setRate(325);

        expect(current().canSave, isFalse);
        expect(() => notifier().saveScenario('x'), throwsStateError);
      });

      test('delete removes the row and its selection', () async {
        when(() => repository.list()).thenAnswer(
          (_) async => [testScenario(), testScenario(id: 's2', label: 'B')],
        );
        when(() => repository.delete(any())).thenAnswer((_) async {});
        await container.read(simulatorControllerProvider.future);
        await notifier().toggleSelection('s1');

        await notifier().deleteScenario('s1');

        verify(() => repository.delete('s1')).called(1);
        expect(current().scenarios.map((s) => s.id), ['s2']);
        expect(current().selection, isEmpty);
      });

      test('a refused delete keeps the row and reports it', () async {
        when(() => repository.list()).thenAnswer((_) async => [testScenario()]);
        when(() => repository.delete(any())).thenThrow(
          const ApiFailure(code: 'SIMULATION_NOT_FOUND', message: 'gone'),
        );
        await container.read(simulatorControllerProvider.future);

        await notifier().deleteScenario('s1');

        expect(current().scenarios, hasLength(1));
        expect(current().actionError, isA<ApiFailure>());
      });
    });

    group('compare selection', () {
      setUp(() {
        when(() => repository.list()).thenAnswer(
          (_) async => [
            testScenario(),
            testScenario(id: 's2', label: 'Lyon 7e — 350 k€'),
            testScenario(id: 's3', label: 'Lyon 8e — 290 k€'),
          ],
        );
      });

      test('the live row counts toward the cap of 3', () async {
        await container.read(simulatorControllerProvider.future);
        typeFrameInputs();
        await _settle();

        await notifier().toggleSelection(SimulatorState.liveId);
        await notifier().toggleSelection('s1');
        await notifier().toggleSelection('s2');
        await notifier().toggleSelection('s3');

        expect(current().selection, [SimulatorState.liveId, 's1', 's2']);
        expect(current().selectionFull, isTrue);
        expect(current().isSelectable('s3'), isFalse);
        expect(current().isSelectable('s2'), isTrue);

        await notifier().toggleSelection('s2');
        expect(current().isSelectable('s3'), isTrue);
      });

      test('the live row cannot be checked before it computes', () async {
        await container.read(simulatorControllerProvider.future);

        await notifier().toggleSelection(SimulatorState.liveId);

        expect(current().isSelectable(SimulatorState.liveId), isFalse);
        expect(current().selection, isEmpty);
      });

      test(
        'comparison needs two columns and reads the ratio both ways',
        () async {
          when(
            () => repository.compute(any(), includeExistingLoans: true),
          ).thenAnswer((_) async => testOverLimitResult());
          await container.read(simulatorControllerProvider.future);

          await notifier().toggleSelection('s1');
          expect(current().canOpenComparison, isFalse);
          await notifier().openComparison();
          expect(current().comparison, isNull);

          await notifier().toggleSelection('s2');
          await notifier().openComparison();

          final columns = current().comparison!.value!;
          expect(columns.map((column) => column.id), ['s1', 's2']);
          expect(columns.first.result.debtRatioBps, 3084);
          expect(columns.first.ratioWithExistingBps, 6358);

          await notifier().toggleSelection('s2');
          expect(current().comparison, isNull);
        },
      );
    });

    test('declaring an income re-reads the household and recomputes', () async {
      when(() => repository.declareIncome(any())).thenAnswer((_) async {});
      await container.read(simulatorControllerProvider.future);
      typeFrameInputs();
      await _settle();

      when(
        () => repository.household(),
      ).thenAnswer((_) async => testHousehold(monthlyIncomeMinor: 520000));
      await notifier().declareIncome(520000);
      await _settle();

      verify(() => repository.declareIncome(520000)).called(1);
      expect(current().household.monthlyIncomeMinor, 520000);
      verify(
        () => repository.compute(testTerms, includeExistingLoans: false),
      ).called(2);
    });
  });

  group('repository', () {
    late MockApiClient apiClient;
    late SimulationsRepository repository;

    setUp(() {
      apiClient = MockApiClient();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);
      repository = container.read(simulationsRepositoryProvider);
    });

    test('compute sends the terms and maps the engine figures', () async {
      when(
        () => apiClient.post('/simulations/compute', body: any(named: 'body')),
      ).thenAnswer((_) async => resultJson());

      final result = await repository.compute(
        testTerms,
        includeExistingLoans: true,
      );

      final body =
          verify(
                () => apiClient.post(
                  '/simulations/compute',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body, {
        'principal_minor': 28450000,
        'annual_rate_bps': 325,
        'insurance_monthly_minor': 3200,
        'term_months': 300,
        'upfront_fees_minor': 450000,
        'property_price_minor': 32000000,
        'down_payment_minor': 4000000,
        'include_existing_loans': true,
      });
      expect(result.totalInstalmentMinor, 141841);
      expect(result.taegBps, 367);
      expect(result.yearly.single.principalMinor, 493322);
      expect(result.yearly.single.interestMinor, 616000);
      expect(result.hcsf.limitBps, 3500);
      expect(result.maxBorrowableMinor, 32292849);
    });

    test('compute maps absent figures to null, not zero', () async {
      when(
        () => apiClient.post('/simulations/compute', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => resultJson(
          debtRatioBps: null,
          withinRatio: null,
          maxBorrowableMinor: null,
          availableInstalmentMinor: null,
          costOverPriceBps: null,
        ),
      );

      final result = await repository.compute(
        const SimulationTerms(
          principalMinor: 20000000,
          annualRateBps: 325,
          insuranceMonthlyMinor: 0,
          termMonths: 300,
          upfrontFeesMinor: 0,
        ),
        includeExistingLoans: false,
      );

      final body =
          verify(
                () => apiClient.post(
                  '/simulations/compute',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body.containsKey('property_price_minor'), isFalse);
      expect(result.debtRatioBps, isNull);
      expect(result.maxBorrowableMinor, isNull);
      expect(result.costOverPriceBps, isNull);
      expect(result.hcsf.withinRatio, isNull);
    });

    test('list, create and delete speak the scenario endpoints', () async {
      when(
        () => apiClient.get('/simulations'),
      ).thenAnswer((_) async => [scenarioJson()]);
      when(
        () => apiClient.post('/simulations', body: any(named: 'body')),
      ).thenAnswer((_) async => scenarioJson(id: 's2', label: 'Lyon 3e'));
      when(() => apiClient.delete('/simulations/s1')).thenAnswer((_) async {});

      final listed = await repository.list();
      final created = await repository.create('Lyon 3e', testTerms);
      await repository.delete('s1');

      expect(listed.single.terms.propertyPriceMinor, 26500000);
      expect(created.id, 's2');
      final body =
          verify(
                () => apiClient.post(
                  '/simulations',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body['label'], 'Lyon 3e');
      expect(body['property_price_minor'], 32000000);
      expect(body.containsKey('include_existing_loans'), isFalse);
      verify(() => apiClient.delete('/simulations/s1')).called(1);
    });

    test(
      'household reads the charge and the income from the summary',
      () async {
        when(() => apiClient.get('/mortgages/summary')).thenAnswer(
          (_) async =>
              householdJson(monthlyIncomeMinor: null, incomeSource: 'unknown'),
        );

        final household = await repository.household();

        expect(household.existingChargeMinor, 150625);
        expect(household.monthlyIncomeMinor, isNull);
        expect(household.incomeSource, IncomeSource.unknown);
      },
    );
  });
}
