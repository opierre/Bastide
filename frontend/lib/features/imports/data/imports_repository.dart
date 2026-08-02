import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/csv_template.dart';
import '../domain/import_batch.dart';

/// Calls the `/imports` and `/csv-templates` endpoints and maps the wire JSON
/// to domain models. The only place in the imports feature that knows the
/// response shape. `ApiClient` already maps the `{error:{code,message}}`
/// envelope to [ApiFailure], so failures simply propagate.
class ImportsRepository {
  ImportsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ImportBatch>> listBatches() async {
    final json = await _apiClient.get('/imports') as List<dynamic>;
    return json.map((entry) => _parseBatch(entry as Map<String, dynamic>)).toList();
  }

  /// Uploads a statement file. Passing [csvTemplateId] parses it as CSV with
  /// that saved mapping; omitting it parses the file as OFX/QFX.
  ///
  /// Re-uploading a file already imported into the account is a no-op on the
  /// backend, which returns the original batch — so a double import shows the
  /// first result rather than an error.
  Future<ImportBatch> importFile({
    required String accountId,
    required String fileName,
    required List<int> bytes,
    String? csvTemplateId,
  }) async {
    final json = await _apiClient.postMultipart(
      '/imports',
      fileField: 'file',
      fileName: fileName,
      fileBytes: bytes,
      fields: {
        'account_id': accountId,
        'csv_template_id': ?csvTemplateId,
      },
    );
    return _parseBatch(json as Map<String, dynamic>);
  }

  Future<List<CsvTemplate>> listTemplates() async {
    final json = await _apiClient.get('/csv-templates') as List<dynamic>;
    return json.map((entry) => _parseTemplate(entry as Map<String, dynamic>)).toList();
  }

  Future<CsvTemplate> createTemplate(CsvTemplateDraft draft) async {
    final json = await _apiClient.post(
      '/csv-templates',
      body: {
        'bank_name': draft.bankName,
        'delimiter': draft.delimiter,
        'encoding': draft.encoding,
        'date_format': draft.dateFormat,
        'decimal_separator': draft.decimalSeparator,
        'amount_strategy': draft.amountStrategy.wireValue,
        'column_map': draft.columnMap,
        'header_offset': draft.headerOffset,
      },
    );
    return _parseTemplate(json as Map<String, dynamic>);
  }

  /// Parses a sample of [bytes] against a candidate mapping without saving
  /// anything — the wizard's live preview.
  ///
  /// The endpoint is multipart, so every field is a flat string; `column_map`
  /// travels JSON-encoded, which is what the backend expects.
  Future<List<CsvPreviewRow>> previewTemplate({
    required CsvTemplateDraft draft,
    required String fileName,
    required List<int> bytes,
  }) async {
    final json = await _apiClient.postMultipart(
      '/csv-templates/preview',
      fileField: 'file',
      fileName: fileName,
      fileBytes: bytes,
      fields: {
        'bank_name': draft.bankName,
        'delimiter': draft.delimiter,
        'encoding': draft.encoding,
        'date_format': draft.dateFormat,
        'decimal_separator': draft.decimalSeparator,
        'amount_strategy': draft.amountStrategy.wireValue,
        'column_map': jsonEncode(draft.columnMap),
        'header_offset': '${draft.headerOffset}',
      },
    );
    return (json as List<dynamic>)
        .map((entry) => _parsePreviewRow(entry as Map<String, dynamic>))
        .toList();
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
    importedAt: DateTime.parse(json['imported_at'] as String),
  );

  CsvTemplate _parseTemplate(Map<String, dynamic> json) => CsvTemplate(
    id: json['id'] as String,
    draft: CsvTemplateDraft(
      bankName: json['bank_name'] as String,
      delimiter: json['delimiter'] as String,
      encoding: json['encoding'] as String,
      dateFormat: json['date_format'] as String,
      decimalSeparator: json['decimal_separator'] as String,
      amountStrategy: AmountStrategy.fromWire(json['amount_strategy'] as String),
      columnMap: (json['column_map'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      headerOffset: json['header_offset'] as int,
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  CsvPreviewRow _parsePreviewRow(Map<String, dynamic> json) => CsvPreviewRow(
    bookedDate: DateTime.parse(json['booked_date'] as String),
    valueDate: json['value_date'] == null
        ? null
        : DateTime.parse(json['value_date'] as String),
    amountMinor: json['amount_minor'] as int,
    descriptionRaw: json['description_raw'] as String,
  );
}

final importsRepositoryProvider = Provider<ImportsRepository>((ref) {
  return ImportsRepository(ref.watch(apiClientProvider));
});
