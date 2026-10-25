import 'package:bastide/features/imports/application/imports_controller.dart';
import 'package:bastide/features/imports/domain/import_batch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No-network `ImportsController` double: a fixed history and a canned import
/// result, so widget tests can drive the panel without an API client.
class FakeImportsController extends ImportsController {
  FakeImportsController({
    this.initialBatches = const [],
    this.importResult,
    this.importResults = const [],
    this.errorOnImport,
  });

  final List<ImportBatch> initialBatches;

  /// The batch every import returns, unless [importResults] gives one per call.
  final ImportBatch? importResult;

  /// One batch per import call, in order — for a file covering several
  /// accounts, which the panel imports one statement at a time.
  final List<ImportBatch> importResults;
  final Object? errorOnImport;

  /// What the panel asked to import, so a test can assert *which account* a
  /// statement was filed against — the whole point of reading the destination
  /// out of the file rather than off a selector.
  final importCalls =
      <({String accountId, String fileName, String? statement})>[];

  @override
  Future<List<ImportBatch>> build() async => initialBatches;

  @override
  Future<ImportBatch> importFile({
    required String accountId,
    required PickedImportFile file,
    String? statement,
  }) async {
    importCalls.add((
      accountId: accountId,
      fileName: file.name,
      statement: statement,
    ));
    if (errorOnImport != null) throw errorOnImport!;
    final batch = importResult ?? importResults[importCalls.length - 1];
    state = AsyncValue.data([batch, ...?state.value]);
    return batch;
  }
}
