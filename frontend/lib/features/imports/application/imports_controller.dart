import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/accounts_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../transactions/application/transactions_controller.dart';
import '../data/imports_repository.dart';
import '../domain/import_batch.dart';

/// Extensions the file picker and the drop target both accept.
const importFileExtensions = ['ofx', 'qfx'];

/// A file the user has chosen but not yet imported, held in memory.
///
/// Bytes rather than a path: the sidecar takes the file as a multipart upload,
/// and a statement is small enough that reading it once up front is simpler
/// than keeping a handle open until the user commits it.
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
}

/// Opens the native file dialog. Behind an interface so widget tests can drive
/// the panel without a platform channel — see the testing skill.
class ImportFilePicker {
  const ImportFilePicker();

  Future<PickedImportFile?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'OFX / QFX', extensions: importFileExtensions),
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

  /// Imports [file] into [accountId].
  ///
  /// Returns the batch so the panel can show its result. A `failed` batch is a
  /// normal return, not a throw: the backend records the rejected file in the
  /// history with its error message, and the panel reports it calmly.
  Future<ImportBatch> importFile({
    required String accountId,
    required PickedImportFile file,
  }) async {
    final batch = await ref
        .read(importsRepositoryProvider)
        .importFile(accountId: accountId, fileName: file.name, bytes: file.bytes);

    // Re-importing an identical file returns the original batch rather than a
    // new one, so replace a matching entry instead of listing it twice.
    final history = state.value ?? const <ImportBatch>[];
    state = AsyncValue.data([
      batch,
      ...history.where((existing) => existing.id != batch.id),
    ]);

    // An import writes rows and moves the account's balance, so every panel reading
    // either is stale the moment it lands — without this, the transactions list only
    // caught up on a restart. Invalidated rather than refetched here: the panels that
    // are actually being watched reload themselves, the ones that aren't stay idle.
    // A `failed` batch wrote nothing, so it leaves them alone.
    if (batch.status != ImportStatus.failed) {
      ref.invalidate(transactionsControllerProvider);
      ref.invalidate(accountsControllerProvider);
      ref.invalidate(dashboardControllerProvider);
    }
    return batch;
  }
}

final importsControllerProvider =
    AsyncNotifierProvider<ImportsController, List<ImportBatch>>(ImportsController.new);

/// The account the user picked to settle a statement that couldn't name its own
/// destination — an ambiguous match, or a file with no readable account block.
///
/// Not a destination selector: it is empty on every well-formed statement, and
/// is only ever consulted when [ofxAccountDetectionProvider] came back without
/// an answer. Cleared whenever the staged file changes, so a choice made for
/// one statement can never carry over to the next.
class ChosenImportAccount extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? accountId) => state = accountId;

  void clear() => state = null;
}

final chosenImportAccountProvider = NotifierProvider<ChosenImportAccount, String?>(
  ChosenImportAccount.new,
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
