import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/imports_repository.dart';
import '../domain/csv_template.dart';
import '../domain/import_batch.dart';

/// Extensions the file picker and the drop target both accept.
const importFileExtensions = ['ofx', 'qfx', 'csv'];

/// A file the user has chosen but not yet imported, held in memory.
///
/// Bytes rather than a path: the sidecar takes the file as a multipart upload,
/// and a statement is small enough that reading it once up front is simpler
/// than keeping a handle open across the wizard's lifetime.
@immutable
class PickedImportFile {
  const PickedImportFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  /// Lowercased extension, or `''` when the name carries none.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// CSV needs a column mapping before it can be parsed; OFX/QFX are
  /// self-describing and import in one step.
  bool get needsCsvTemplate => extension == 'csv';
}

/// Opens the native file dialog. Behind an interface so widget tests can drive
/// the panel without a platform channel — see the testing skill.
class ImportFilePicker {
  const ImportFilePicker();

  Future<PickedImportFile?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'OFX / QFX / CSV', extensions: importFileExtensions),
      ],
    );
    if (file == null) return null;
    return PickedImportFile(name: file.name, bytes: await file.readAsBytes());
  }
}

final importFilePickerProvider = Provider<ImportFilePicker>(
  (ref) => const ImportFilePicker(),
);

/// Import history, most recent first, and the import action itself.
///
/// A successful import prepends its batch instead of refetching: the response
/// *is* the new history entry, so a second round trip would only re-read what
/// we already hold. Failures propagate to the caller rather than replacing
/// `state` — a rejected file shouldn't blank out the history behind it.
class ImportsController extends AsyncNotifier<List<ImportBatch>> {
  @override
  Future<List<ImportBatch>> build() => ref.read(importsRepositoryProvider).listBatches();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(importsRepositoryProvider).listBatches(),
    );
  }

  /// Imports [file] into [accountId], as CSV when [csvTemplateId] is given and
  /// as OFX/QFX otherwise.
  ///
  /// Returns the batch so the panel can show its result. A `failed` batch is a
  /// normal return, not a throw: the backend records the rejected file in the
  /// history with its error message, and the panel reports it calmly.
  Future<ImportBatch> importFile({
    required String accountId,
    required PickedImportFile file,
    String? csvTemplateId,
  }) async {
    final batch = await ref
        .read(importsRepositoryProvider)
        .importFile(
          accountId: accountId,
          fileName: file.name,
          bytes: file.bytes,
          csvTemplateId: csvTemplateId,
        );

    // Re-importing an identical file returns the original batch rather than a
    // new one, so replace a matching entry instead of listing it twice.
    final history = state.value ?? const <ImportBatch>[];
    state = AsyncValue.data([
      batch,
      ...history.where((existing) => existing.id != batch.id),
    ]);
    return batch;
  }

  /// Parses a sample of [file] against a candidate mapping without saving
  /// anything — the wizard's live preview.
  Future<List<CsvPreviewRow>> previewCsv({
    required CsvTemplateDraft draft,
    required PickedImportFile file,
  }) {
    return ref
        .read(importsRepositoryProvider)
        .previewTemplate(draft: draft, fileName: file.name, bytes: file.bytes);
  }
}

final importsControllerProvider =
    AsyncNotifierProvider<ImportsController, List<ImportBatch>>(ImportsController.new);

/// The user's saved per-bank CSV mappings.
class CsvTemplatesController extends AsyncNotifier<List<CsvTemplate>> {
  @override
  Future<List<CsvTemplate>> build() => ref.read(importsRepositoryProvider).listTemplates();

  Future<CsvTemplate> create(CsvTemplateDraft draft) async {
    final template = await ref.read(importsRepositoryProvider).createTemplate(draft);
    state = AsyncValue.data([...?state.value, template]);
    return template;
  }

  /// The saved mapping for [institution], if one exists.
  ///
  /// Matched on the bank name the template was saved under, case- and
  /// whitespace-insensitively, since it is typed by hand in both places. This
  /// is what lets a second import from the same bank skip the wizard.
  CsvTemplate? templateFor(String institution) {
    final needle = institution.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final template in state.value ?? const <CsvTemplate>[]) {
      if (template.bankName.trim().toLowerCase() == needle) return template;
    }
    return null;
  }
}

final csvTemplatesControllerProvider =
    AsyncNotifierProvider<CsvTemplatesController, List<CsvTemplate>>(
      CsvTemplatesController.new,
    );

/// The destination account chosen in the panel.
class SelectedImportAccount extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? accountId) => state = accountId;
}

final selectedImportAccountProvider = NotifierProvider<SelectedImportAccount, String?>(
  SelectedImportAccount.new,
);

/// The file staged in the drop zone, before it is imported.
class SelectedImportFile extends Notifier<PickedImportFile?> {
  @override
  PickedImportFile? build() => null;

  void select(PickedImportFile? file) => state = file;

  void clear() => state = null;
}

final selectedImportFileProvider =
    NotifierProvider<SelectedImportFile, PickedImportFile?>(SelectedImportFile.new);

/// The batch from the import run in this session, shown in the result card.
///
/// Separate from the history list because it answers a different question —
/// "what just happened" rather than "what have I imported" — and it stays
/// empty until the user actually imports something.
class LastImportResult extends Notifier<ImportBatch?> {
  @override
  ImportBatch? build() => null;

  void set(ImportBatch? batch) => state = batch;
}

final lastImportResultProvider = NotifierProvider<LastImportResult, ImportBatch?>(
  LastImportResult.new,
);
