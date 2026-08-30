import 'package:finstride/features/imports/application/imports_controller.dart';
import 'package:finstride/features/imports/domain/import_batch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No-network `ImportsController` double: a fixed history and a canned import
/// result, so widget tests can drive the panel without an API client.
class FakeImportsController extends ImportsController {
  FakeImportsController({
    this.initialBatches = const [],
    this.importResult,
    this.errorOnImport,
  });

  final List<ImportBatch> initialBatches;
  final ImportBatch? importResult;
  final Object? errorOnImport;

  /// What the panel asked to import, so a test can assert *which account* a
  /// statement was filed against — the whole point of reading the destination
  /// out of the file rather than off a selector.
  final importCalls = <({String accountId, String fileName})>[];

  @override
  Future<List<ImportBatch>> build() async => initialBatches;

  @override
  Future<ImportBatch> importFile({
    required String accountId,
    required PickedImportFile file,
  }) async {
    importCalls.add((accountId: accountId, fileName: file.name));
    if (errorOnImport != null) throw errorOnImport!;
    final batch = importResult!;
    state = AsyncValue.data([batch, ...?state.value]);
    return batch;
  }
}
