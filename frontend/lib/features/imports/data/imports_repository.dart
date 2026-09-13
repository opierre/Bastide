import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/import_batch.dart';

/// Calls the `/imports` endpoints and maps the wire JSON to domain models. The
/// only place in the imports feature that knows the response shape. `ApiClient`
/// already maps the `{error:{code,message}}` envelope to [ApiFailure], so
/// failures simply propagate.
class ImportsRepository {
  ImportsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ImportBatch>> listBatches() async {
    final json = await _apiClient.get('/imports') as List<dynamic>;
    return json
        .map((entry) => _parseBatch(entry as Map<String, dynamic>))
        .toList();
  }

  /// Uploads an OFX/QFX statement.
  ///
  /// Re-uploading a file already imported into the account is a no-op on the
  /// backend, which returns the original batch — so a double import shows the
  /// first result rather than an error.
  Future<ImportBatch> importFile({
    required String accountId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final json = await _apiClient.postMultipart(
      '/imports',
      fileField: 'file',
      fileName: fileName,
      fileBytes: bytes,
      fields: {'account_id': accountId},
    );
    return _parseBatch(json as Map<String, dynamic>);
  }

  ImportBatch _parseBatch(Map<String, dynamic> json) => ImportBatch(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    sourceFormat: ImportFormat.fromWire(json['source_format'] as String),
    fileName: json['file_name'] as String,
    fileHash: json['file_hash'] as String,
    periodStart: DateTime.parse(json['period_start'] as String),
    periodEnd: DateTime.parse(json['period_end'] as String),
    transactionCount: json['transaction_count'] as int,
    newCount: json['new_count'] as int,
    duplicateCount: json['duplicate_count'] as int,
    status: ImportStatus.fromWire(json['status'] as String),
    errorMessage: json['error_message'] as String?,
    balanceMismatchMinor: json['balance_mismatch_minor'] as int?,
    balanceMismatchAsOf: json['balance_mismatch_as_of'] == null
        ? null
        : DateTime.parse(json['balance_mismatch_as_of'] as String),
    importedAt: DateTime.parse(json['imported_at'] as String),
  );
}

final importsRepositoryProvider = Provider<ImportsRepository>((ref) {
  return ImportsRepository(ref.watch(apiClientProvider));
});
