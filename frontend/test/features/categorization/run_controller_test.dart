import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/categorization/application/run_controller.dart';
import 'package:finstride/features/categorization/domain/categorization_run.dart';
import 'package:finstride/features/transactions/application/transactions_controller.dart';
import 'package:finstride/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_transactions_controller.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _runJson({
  String id = 'run-1',
  String status = 'running',
  int total = 200,
  int processed = 0,
  int assigned = 0,
  int deferred = 0,
  int failed = 0,
}) => {
  'id': id,
  'account_id': null,
  'import_batch_id': null,
  'trigger': 'manual',
  'status': status,
  'model_tag': 'gemma-4-e4b',
  'total_count': total,
  'processed_count': processed,
  'assigned_count': assigned,
  'deferred_count': deferred,
  'failed_count': failed,
  'error_message': null,
  'started_at': '2026-05-14T10:00:00Z',
  'finished_at': null,
  'created_at': '2026-05-14T10:00:00Z',
};

const _emptyPage = TransactionsPage(
  items: <Transaction>[],
  page: 1,
  pageSize: 50,
  total: 0,
);

void main() {
  late MockApiClient apiClient;
  late FakeTransactionsController transactions;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    transactions = FakeTransactionsController(initialPage: _emptyPage);
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        transactionsControllerProvider.overrideWith(() => transactions),
      ],
    );
    addTearDown(container.dispose);
  });

  /// The controller is `autoDispose`, so something has to be watching it for
  /// it to stay alive at all — in the app that is the review queue.
  ProviderSubscription<RunState> keepAlive() =>
      container.listen(runControllerProvider, (_, _) {}, fireImmediately: true);

  testWidgets('start posts the requested scope and holds the returned run', (
    tester,
  ) async {
    when(
      () => apiClient.post('/categorization/runs', body: any(named: 'body')),
    ).thenAnswer((_) async => _runJson(status: 'pending'));
    final subscription = keepAlive();

    await container.read(runControllerProvider.notifier).start(accountId: 'a1');

    final captured = verify(
      () => apiClient.post(
        '/categorization/runs',
        body: captureAny(named: 'body'),
      ),
    ).captured.single;
    expect(captured, {'account_id': 'a1', 'scope': 'pending'});
    expect(container.read(runControllerProvider).run?.id, 'run-1');
    expect(container.read(runControllerProvider).isRunning, isTrue);

    // Disposing the controller is what stops the poll; the pump lets Riverpod's
    // own dispose task run, so no timer outlives the test.
    subscription.close();
    container.dispose();
    await tester.pump(runPollInterval);
  });

  testWidgets('polls until a terminal status, then stops', (tester) async {
    when(
      () => apiClient.post('/categorization/runs', body: any(named: 'body')),
    ).thenAnswer((_) async => _runJson(status: 'running', processed: 0));

    final replies = [
      _runJson(status: 'running', processed: 80, assigned: 60, deferred: 20),
      _runJson(
        status: 'success',
        total: 200,
        processed: 200,
        assigned: 150,
        deferred: 50,
      ),
    ];
    var call = 0;
    when(
      () => apiClient.get('/categorization/runs/run-1'),
    ).thenAnswer((_) async => replies[call++]);

    keepAlive();
    await container.read(runControllerProvider.notifier).start();

    await tester.pump(runPollInterval);
    await tester.pump();
    expect(container.read(runControllerProvider).run?.processedCount, 80);

    await tester.pump(runPollInterval);
    await tester.pump();
    expect(
      container.read(runControllerProvider).run?.status,
      RunStatus.success,
    );
    expect(container.read(runControllerProvider).isRunning, isFalse);

    // The poll must be gone, not merely idle: a terminal run is never going to
    // change again, and a live timer here is a conversation with the sidecar
    // that never ends.
    await tester.pump(runPollInterval * 5);
    await tester.pump();
    verify(() => apiClient.get('/categorization/runs/run-1')).called(2);
  });

  testWidgets('refreshes the transaction list as batches land', (tester) async {
    when(
      () => apiClient.post('/categorization/runs', body: any(named: 'body')),
    ).thenAnswer((_) async => _runJson(status: 'running', processed: 0));
    when(() => apiClient.get('/categorization/runs/run-1')).thenAnswer(
      (_) async => _runJson(status: 'success', processed: 200, assigned: 200),
    );

    keepAlive();
    await container.read(runControllerProvider.notifier).start();
    // Once for the accepted run, once for the batch that finished it.
    expect(transactions.refreshQuietlyCalls, 1);

    await tester.pump(runPollInterval);
    await tester.pump();
    expect(transactions.refreshQuietlyCalls, 2);
  });

  testWidgets('cancel moves the run to cancelled and stops polling', (
    tester,
  ) async {
    when(
      () => apiClient.post('/categorization/runs', body: any(named: 'body')),
    ).thenAnswer((_) async => _runJson(status: 'running'));
    when(() => apiClient.post('/categorization/runs/run-1/cancel')).thenAnswer(
      (_) async => _runJson(
        status: 'cancelled',
        processed: 80,
        assigned: 60,
        deferred: 20,
      ),
    );

    keepAlive();
    await container.read(runControllerProvider.notifier).start();
    await container.read(runControllerProvider.notifier).cancel();

    expect(
      container.read(runControllerProvider).run?.status,
      RunStatus.cancelled,
    );
    expect(container.read(runControllerProvider).isRunning, isFalse);

    await tester.pump(runPollInterval * 3);
    await tester.pump();
    verifyNever(() => apiClient.get(any()));
  });

  testWidgets('disposing the panel cancels the timer', (tester) async {
    when(
      () => apiClient.post('/categorization/runs', body: any(named: 'body')),
    ).thenAnswer((_) async => _runJson(status: 'running'));
    when(
      () => apiClient.get('/categorization/runs/run-1'),
    ).thenAnswer((_) async => _runJson(status: 'running', processed: 40));

    final subscription = container.listen(runControllerProvider, (_, _) {});
    await container.read(runControllerProvider.notifier).start();

    await tester.pump(runPollInterval);
    await tester.pump();
    verify(() => apiClient.get('/categorization/runs/run-1')).called(1);

    // Dropping the last listener disposes the `autoDispose` controller, the way
    // leaving the transactions panel does.
    subscription.close();

    await tester.pump(runPollInterval * 4);
    await tester.pump();
    verifyNever(() => apiClient.get('/categorization/runs/run-1'));
  });

  testWidgets('a failed start is reported without losing the queue', (
    tester,
  ) async {
    when(
      () => apiClient.post('/categorization/runs', body: any(named: 'body')),
    ).thenThrow(
      const ApiFailure(code: 'INFERENCE_UNAVAILABLE', message: 'no runtime'),
    );
    final subscription = keepAlive();

    await container.read(runControllerProvider.notifier).start();

    final state = container.read(runControllerProvider);
    expect(state.error, isA<ApiFailure>());
    expect(state.run, isNull);
    expect(state.isStarting, isFalse);

    subscription.close();
    container.dispose();
    await tester.pump(runPollInterval);
  });

  test(
    'availability skips the health probe when the user has not opted in',
    () async {
      when(() => apiClient.get('/settings')).thenAnswer(
        (_) async => {
          'ai_enabled': false,
          'inference_base_url': 'http://127.0.0.1:11434/v1',
          'model_tag': null,
          'confidence_threshold': 0.8,
        },
      );

      final availability = await container.read(aiAvailabilityProvider.future);

      expect(availability.isActive, isFalse);
      verifyNever(() => apiClient.get('/settings/inference/health'));
    },
  );

  test('availability is inactive when the runtime does not answer', () async {
    when(() => apiClient.get('/settings')).thenAnswer(
      (_) async => {
        'ai_enabled': true,
        'inference_base_url': 'http://127.0.0.1:11434/v1',
        'model_tag': null,
        'confidence_threshold': 0.8,
      },
    );
    when(() => apiClient.get('/settings/inference/health')).thenAnswer(
      (_) async => {
        'reachable': false,
        'models': <String>[],
        'detail': 'connection refused',
      },
    );

    final availability = await container.read(aiAvailabilityProvider.future);

    expect(availability.enabled, isTrue);
    expect(availability.reachable, isFalse);
    expect(availability.isActive, isFalse);
  });

  test('a broken availability lookup degrades instead of raising', () async {
    when(() => apiClient.get('/settings')).thenThrow(Exception('sidecar down'));

    expect(
      await container.read(aiAvailabilityProvider.future),
      AiAvailability.unavailable,
    );
  });
}
