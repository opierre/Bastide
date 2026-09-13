import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/imports/application/imports_controller.dart';
import 'package:finstride/features/imports/domain/import_batch.dart';
import 'package:finstride/features/transactions/application/transactions_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _batchJson({
  String id = 'b1',
  String sourceFormat = 'ofx',
  String fileName = 'releve.ofx',
  String fileHash = 'hash-1',
  int transactionCount = 45,
  int newCount = 42,
  int duplicateCount = 3,
  String status = 'success',
  String? errorMessage,
}) => {
  'id': id,
  'account_id': 'a1',
  'source_format': sourceFormat,
  'file_name': fileName,
  'file_hash': fileHash,
  'period_start': '2026-05-01',
  'period_end': '2026-05-31',
  'transaction_count': transactionCount,
  'new_count': newCount,
  'duplicate_count': duplicateCount,
  'status': status,
  'error_message': errorMessage,
  'imported_at': '2026-06-01T09:30:00Z',
};

/// An empty transactions page — enough for the list to load, since the tests that
/// use it only care about *whether* it was fetched again.
const _transactionsPageJson = {
  'items': <Map<String, dynamic>>[],
  'page': 1,
  'page_size': 50,
  'total': 0,
};

const _file = PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]);

/// Stubs the multipart upload, which every import and preview goes through.
void _stubMultipart(MockApiClient apiClient, String path, Object? response) {
  when(
    () => apiClient.postMultipart(
      path,
      fileField: any(named: 'fileField'),
      fileName: any(named: 'fileName'),
      fileBytes: any(named: 'fileBytes'),
      fields: any(named: 'fields'),
    ),
  ).thenAnswer((_) async => response);
}

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  group('ImportsController', () {
    test('build loads the import history', () async {
      when(
        () => apiClient.get('/imports'),
      ).thenAnswer((_) async => [_batchJson()]);

      final batches = await container.read(importsControllerProvider.future);

      expect(batches, hasLength(1));
      expect(batches.single.fileName, 'releve.ofx');
      expect(batches.single.sourceFormat, ImportFormat.ofx);
      expect(batches.single.status, ImportStatus.success);
      expect(batches.single.newCount, 42);
      expect(batches.single.duplicateCount, 3);
      expect(batches.single.periodStart, DateTime.parse('2026-05-01'));
      expect(batches.single.periodEnd, DateTime.parse('2026-05-31'));
    });

    test('a successful import prepends its batch to the history', () async {
      when(
        () => apiClient.get('/imports'),
      ).thenAnswer((_) async => [_batchJson(id: 'b0')]);
      _stubMultipart(apiClient, '/imports', _batchJson(id: 'b1'));

      await container.read(importsControllerProvider.future);
      final batch = await container
          .read(importsControllerProvider.notifier)
          .importFile(accountId: 'a1', file: _file);

      expect(batch.id, 'b1');
      expect(batch.status, ImportStatus.success);
      final history = container.read(importsControllerProvider).value!;
      expect(history.map((entry) => entry.id), ['b1', 'b0']);
    });

    test(
      'the upload carries the destination account and nothing else',
      () async {
        when(
          () => apiClient.get('/imports'),
        ).thenAnswer((_) async => <dynamic>[]);
        _stubMultipart(apiClient, '/imports', _batchJson());

        await container.read(importsControllerProvider.future);
        await container
            .read(importsControllerProvider.notifier)
            .importFile(accountId: 'a1', file: _file);

        final captured =
            verify(
                  () => apiClient.postMultipart(
                    '/imports',
                    fileField: any(named: 'fileField'),
                    fileName: any(named: 'fileName'),
                    fileBytes: any(named: 'fileBytes'),
                    fields: captureAny(named: 'fields'),
                  ),
                ).captured.single
                as Map<String, String>;

        expect(captured, {'account_id': 'a1'});
      },
    );

    test(
      're-importing the same file replaces its entry instead of listing it twice',
      () async {
        // The backend returns the *original* batch for an already-imported file,
        // so the history must not grow a second identical row.
        when(
          () => apiClient.get('/imports'),
        ).thenAnswer((_) async => [_batchJson(id: 'b1')]);
        _stubMultipart(
          apiClient,
          '/imports',
          _batchJson(id: 'b1', newCount: 0, duplicateCount: 45),
        );

        await container.read(importsControllerProvider.future);
        final batch = await container
            .read(importsControllerProvider.notifier)
            .importFile(accountId: 'a1', file: _file);

        expect(batch.newCount, 0);
        expect(batch.duplicateCount, 45);
        final history = container.read(importsControllerProvider).value!;
        expect(history, hasLength(1));
        expect(history.single.duplicateCount, 45);
      },
    );

    test('a failed batch returns normally and lands in the history', () async {
      // An unparseable file is recorded, not thrown: the panel reports it
      // calmly and the history keeps the evidence.
      when(
        () => apiClient.get('/imports'),
      ).thenAnswer((_) async => <dynamic>[]);
      _stubMultipart(
        apiClient,
        '/imports',
        _batchJson(
          id: 'b2',
          transactionCount: 0,
          newCount: 0,
          duplicateCount: 0,
          status: 'failed',
          errorMessage: 'No <STMTTRN> records found',
        ),
      );

      await container.read(importsControllerProvider.future);
      final batch = await container
          .read(importsControllerProvider.notifier)
          .importFile(accountId: 'a1', file: _file);

      expect(batch.status, ImportStatus.failed);
      expect(batch.newCount, 0);
      expect(batch.errorMessage, 'No <STMTTRN> records found');
      expect(container.read(importsControllerProvider).value, hasLength(1));
    });

    test('a successful import invalidates the transactions list', () async {
      // Without this the panel only caught up on a restart: the list had already
      // been fetched, and nothing told it the import had written to it.
      when(
        () => apiClient.get('/imports'),
      ).thenAnswer((_) async => <dynamic>[]);
      when(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).thenAnswer((_) async => _transactionsPageJson);
      _stubMultipart(apiClient, '/imports', _batchJson());

      await container.read(importsControllerProvider.future);
      await container.read(transactionsControllerProvider.future);
      await container
          .read(importsControllerProvider.notifier)
          .importFile(accountId: 'a1', file: _file);
      await container.read(transactionsControllerProvider.future);

      verify(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).called(2);
    });

    test('a failed import leaves the transactions list alone', () async {
      // Nothing was written, so re-reading the list would only cost a round trip.
      when(
        () => apiClient.get('/imports'),
      ).thenAnswer((_) async => <dynamic>[]);
      when(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).thenAnswer((_) async => _transactionsPageJson);
      _stubMultipart(apiClient, '/imports', _batchJson(status: 'failed'));

      await container.read(importsControllerProvider.future);
      await container.read(transactionsControllerProvider.future);
      await container
          .read(importsControllerProvider.notifier)
          .importFile(accountId: 'a1', file: _file);
      await container.read(transactionsControllerProvider.future);

      verify(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).called(1);
    });

    test(
      'an import failure rethrows and leaves the history untouched',
      () async {
        when(
          () => apiClient.get('/imports'),
        ).thenAnswer((_) async => [_batchJson()]);
        when(
          () => apiClient.postMultipart(
            '/imports',
            fileField: any(named: 'fileField'),
            fileName: any(named: 'fileName'),
            fileBytes: any(named: 'fileBytes'),
            fields: any(named: 'fields'),
          ),
        ).thenThrow(
          const ApiFailure(code: 'ACCOUNT_NOT_FOUND', message: 'nope'),
        );

        await container.read(importsControllerProvider.future);

        await expectLater(
          () => container
              .read(importsControllerProvider.notifier)
              .importFile(accountId: 'missing', file: _file),
          throwsA(isA<ApiFailure>()),
        );
        expect(container.read(importsControllerProvider).value, hasLength(1));
      },
    );
  });
}
