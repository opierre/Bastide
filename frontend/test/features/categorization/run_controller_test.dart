import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/runs/run_event.dart';
import 'package:bastide/core/runs/run_progress_client.dart';
import 'package:bastide/core/runs/run_progress_provider.dart';
import 'package:bastide/features/categorization/application/run_controller.dart';
import 'package:bastide/features/categorization/domain/categorization_run.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_transactions_controller.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockRunProgressClient extends Mock implements RunProgressClient {}

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

RunEvent _event(
  RunEventType type, {
  String runId = 'run-1',
  int done = 0,
  int total = 200,
  Map<String, int> counts = const {},
}) => RunEvent(
  runId: runId,
  kind: 'categorization',
  type: type,
  done: done,
  total: total,
  counts: counts,
  occurredAt: DateTime.utc(2026, 5, 14, 10),
);

const _emptyPage = TransactionsPage(
  items: <Transaction>[],
  page: 1,
  pageSize: 50,
  total: 0,
);

void main() {
  late MockApiClient apiClient;
  late MockRunProgressClient progress;
  late StreamController<RunUpdate> updates;
  late FakeTransactionsController transactions;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    progress = MockRunProgressClient();
    updates = StreamController<RunUpdate>.broadcast();
    when(() => progress.watch(any())).thenAnswer((_) => updates.stream);
    transactions = FakeTransactionsController(initialPage: _emptyPage);
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        runProgressClientProvider.overrideWithValue(progress),
        transactionsControllerProvider.overrideWith(() => transactions),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(updates.close);
  });

  /// The controller is `autoDispose`, so something has to be watching it for
  /// it to stay alive at all — in the app that is the review queue.
  ProviderSubscription<RunState> keepAlive() =>
      container.listen(runControllerProvider, (_, _) {}, fireImmediately: true);

  RunState read() => container.read(runControllerProvider);

  Future<void> push(RunUpdate update) async {
    updates.add(update);
    await Future<void>.delayed(Duration.zero);
  }

  void startsWith(Map<String, dynamic> json) => when(
    () => apiClient.post('/categorization/runs', body: any(named: 'body')),
  ).thenAnswer((_) async => json);

  test(
    'start posts the requested scope and follows the returned run',
    () async {
      startsWith(_runJson(status: 'pending'));
      keepAlive();

      await container
          .read(runControllerProvider.notifier)
          .start(accountId: 'a1');

      final captured = verify(
        () => apiClient.post(
          '/categorization/runs',
          body: captureAny(named: 'body'),
        ),
      ).captured.single;
      expect(captured, {'account_id': 'a1', 'scope': 'pending'});
      expect(read().run?.id, 'run-1');
      expect(read().isRunning, isTrue);
      verify(() => progress.watch('run-1')).called(1);
      expect(updates.hasListener, isTrue);
    },
  );

  test('progress events move the run with no REST read', () async {
    startsWith(_runJson(status: 'pending'));
    keepAlive();
    await container.read(runControllerProvider.notifier).start();

    await push(RunResync(_event(RunEventType.started)));
    expect(read().run?.status, RunStatus.running);

    await push(
      RunEventUpdate(
        _event(
          RunEventType.progress,
          done: 80,
          counts: {'assigned': 60, 'deferred': 20, 'failed': 0},
        ),
      ),
    );

    final run = read().run!;
    expect(run.processedCount, 80);
    expect(run.assignedCount, 60);
    expect(run.deferredCount, 20);
    expect(run.status, RunStatus.running);
    verifyNever(() => apiClient.get(any()));
  });

  test('a finish event ends the run, reads the final row once, and '
      'stops listening', () async {
    startsWith(_runJson(status: 'running'));
    when(() => apiClient.get('/categorization/runs/run-1')).thenAnswer(
      (_) async => _runJson(
        status: 'partial',
        processed: 200,
        assigned: 150,
        deferred: 40,
        failed: 10,
      ),
    );
    keepAlive();
    await container.read(runControllerProvider.notifier).start();

    await push(
      RunEventUpdate(
        _event(
          RunEventType.finished,
          done: 200,
          counts: {'assigned': 150, 'deferred': 40, 'failed': 10},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(read().run?.status, RunStatus.partial);
    expect(read().run?.processedCount, 200);
    expect(read().isRunning, isFalse);
    verify(() => apiClient.get('/categorization/runs/run-1')).called(1);
    expect(updates.hasListener, isFalse);
  });

  test('refreshes the transaction list as batches land', () async {
    startsWith(_runJson(status: 'running'));
    keepAlive();
    await container.read(runControllerProvider.notifier).start();
    // Once for the accepted run.
    expect(transactions.refreshQuietlyCalls, 1);

    await push(RunEventUpdate(_event(RunEventType.progress, done: 40)));
    expect(transactions.refreshQuietlyCalls, 2);

    // Same count again: nothing committed, nothing to reload.
    await push(RunEventUpdate(_event(RunEventType.progress, done: 40)));
    expect(transactions.refreshQuietlyCalls, 2);
  });

  test('reconnecting mid-run catches up from the snapshot', () async {
    startsWith(_runJson(status: 'running'));
    when(
      () => apiClient.get('/categorization/runs/run-1'),
    ).thenAnswer((_) async => _runJson(status: 'running', processed: 40));
    keepAlive();
    await container.read(runControllerProvider.notifier).start();
    await push(RunEventUpdate(_event(RunEventType.progress, done: 40)));

    // The socket drops: one REST read stands in while it is down.
    await push(const RunConnectionLost());
    verify(() => apiClient.get('/categorization/runs/run-1')).called(1);
    expect(read().run?.processedCount, 40);

    // Back up: the snapshot carries what was missed.
    await push(RunResync(_event(RunEventType.progress, done: 160)));
    expect(read().run?.processedCount, 160);
    expect(read().isRunning, isTrue);
    verifyNever(() => apiClient.get(any()));
  });

  test('a reconnection that no longer knows the run reads it once', () async {
    startsWith(_runJson(status: 'running'));
    when(() => apiClient.get('/categorization/runs/run-1')).thenAnswer(
      (_) async => _runJson(status: 'success', processed: 200, assigned: 200),
    );
    keepAlive();
    await container.read(runControllerProvider.notifier).start();

    // It ended while the socket was down, so the snapshot is empty.
    await push(const RunResync(null));

    expect(read().run?.status, RunStatus.success);
    expect(read().isRunning, isFalse);
    expect(updates.hasListener, isFalse);
  });

  test('a stale REST read never moves the run backwards', () async {
    startsWith(_runJson(status: 'running'));
    final reply = Completer<Map<String, dynamic>>();
    when(
      () => apiClient.get('/categorization/runs/run-1'),
    ).thenAnswer((_) => reply.future);
    keepAlive();
    await container.read(runControllerProvider.notifier).start();

    await push(const RunConnectionLost());
    await push(RunResync(_event(RunEventType.progress, done: 120)));
    reply.complete(_runJson(status: 'running', processed: 40));
    await Future<void>.delayed(Duration.zero);

    expect(read().run?.processedCount, 120);
  });

  test(
    'a failed REST read is reported and cleared once one succeeds',
    () async {
      startsWith(_runJson(status: 'running'));
      var fail = true;
      when(() => apiClient.get('/categorization/runs/run-1')).thenAnswer((
        _,
      ) async {
        if (fail) {
          throw const ApiFailure(code: 'UNKNOWN_ERROR', message: 'down');
        }
        return _runJson(status: 'running', processed: 60);
      });
      keepAlive();
      await container.read(runControllerProvider.notifier).start();

      await push(const RunConnectionLost());
      expect(read().error, isA<ApiFailure>());
      expect(read().isRunning, isTrue);

      fail = false;
      await push(const RunConnectionLost());
      expect(read().error, isNull);
      expect(read().run?.processedCount, 60);
    },
  );

  test('cancel moves the run to cancelled and stops listening', () async {
    startsWith(_runJson(status: 'running'));
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

    expect(read().run?.status, RunStatus.cancelled);
    expect(read().isRunning, isFalse);
    expect(updates.hasListener, isFalse);
    verifyNever(() => apiClient.get(any()));
  });

  test('the progress stream ending on logout is taken quietly', () async {
    startsWith(_runJson(status: 'running', processed: 40));
    keepAlive();
    await container.read(runControllerProvider.notifier).start();

    // The shared client is replaced on logout and ends its watchers' streams.
    await updates.close();
    await Future<void>.delayed(Duration.zero);

    expect(read().run?.processedCount, 40);
    expect(read().error, isNull);
    verifyNever(() => apiClient.get(any()));
  });

  test('disposing the panel drops the subscription', () async {
    startsWith(_runJson(status: 'running'));
    final subscription = container.listen(runControllerProvider, (_, _) {});
    await container.read(runControllerProvider.notifier).start();
    expect(updates.hasListener, isTrue);

    // Dropping the last listener disposes the `autoDispose` controller, the way
    // leaving the transactions panel does.
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(updates.hasListener, isFalse);
  });

  test('a failed start is reported without losing the queue', () async {
    when(
      () => apiClient.post('/categorization/runs', body: any(named: 'body')),
    ).thenThrow(
      const ApiFailure(code: 'INFERENCE_UNAVAILABLE', message: 'no runtime'),
    );
    keepAlive();

    await container.read(runControllerProvider.notifier).start();

    final state = read();
    expect(state.error, isA<ApiFailure>());
    expect(state.run, isNull);
    expect(state.isStarting, isFalse);
    verifyNever(() => progress.watch(any()));
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
