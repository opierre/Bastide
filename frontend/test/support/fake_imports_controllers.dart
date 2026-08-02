import 'package:finstride/features/imports/application/imports_controller.dart';
import 'package:finstride/features/imports/domain/csv_template.dart';
import 'package:finstride/features/imports/domain/import_batch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No-network `ImportsController` double: a fixed history, a canned import
/// result, and a canned preview — so widget tests can drive the panel and the
/// wizard without an API client.
class FakeImportsController extends ImportsController {
  FakeImportsController({
    this.initialBatches = const [],
    this.importResult,
    this.previewRows = const [],
    this.errorOnImport,
    this.errorOnPreview,
  });

  final List<ImportBatch> initialBatches;
  final ImportBatch? importResult;
  final List<CsvPreviewRow> previewRows;
  final Object? errorOnImport;
  final Object? errorOnPreview;

  final importCalls = <({String accountId, String fileName, String? csvTemplateId})>[];
  final previewCalls = <CsvTemplateDraft>[];

  @override
  Future<List<ImportBatch>> build() async => initialBatches;

  @override
  Future<ImportBatch> importFile({
    required String accountId,
    required PickedImportFile file,
    String? csvTemplateId,
  }) async {
    importCalls.add((
      accountId: accountId,
      fileName: file.name,
      csvTemplateId: csvTemplateId,
    ));
    if (errorOnImport != null) throw errorOnImport!;
    final batch = importResult!;
    state = AsyncValue.data([batch, ...?state.value]);
    return batch;
  }

  @override
  Future<List<CsvPreviewRow>> previewCsv({
    required CsvTemplateDraft draft,
    required PickedImportFile file,
  }) async {
    previewCalls.add(draft);
    if (errorOnPreview != null) throw errorOnPreview!;
    return previewRows;
  }
}

/// No-network `CsvTemplatesController` double.
class FakeCsvTemplatesController extends CsvTemplatesController {
  FakeCsvTemplatesController({this.initialTemplates = const [], this.created});

  final List<CsvTemplate> initialTemplates;

  /// The template `create` resolves to; defaults to echoing the draft back
  /// under a fixed id.
  final CsvTemplate? created;

  final createCalls = <CsvTemplateDraft>[];

  @override
  Future<List<CsvTemplate>> build() async => initialTemplates;

  @override
  Future<CsvTemplate> create(CsvTemplateDraft draft) async {
    createCalls.add(draft);
    final template =
        created ??
        CsvTemplate(id: 't-new', draft: draft, createdAt: DateTime.utc(2026, 5, 1));
    state = AsyncValue.data([...?state.value, template]);
    return template;
  }
}
