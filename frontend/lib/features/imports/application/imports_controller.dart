import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/accounts_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../networth/application/networth_controller.dart';
import '../../transactions/application/transactions_controller.dart';
import '../data/imports_repository.dart';
import '../domain/card_settlement_status.dart';
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
  Future<List<ImportBatch>> build() =>
      ref.read(importsRepositoryProvider).listBatches();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(importsRepositoryProvider).listBatches(),
    );
  }

  /// Imports [file] into [accountId] — only its [statement] (the `ACCTID`)
  /// when the file covers several accounts.
  ///
  /// Returns the batch so the panel can show its result. A `failed` batch is a
  /// normal return, not a throw: the backend records the rejected file in the
  /// history with its error message, and the panel reports it calmly.
  Future<ImportBatch> importFile({
    required String accountId,
    required PickedImportFile file,
    String? statement,
  }) async {
    final batch = await ref
        .read(importsRepositoryProvider)
        .importFile(
          accountId: accountId,
          fileName: file.name,
          bytes: file.bytes,
          statement: statement,
        );

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
      // Synthèse sums the same balances; left cached, it kept the empty state it read
      // before the first import and offered only « Nouveau bien ».
      ref.invalidate(networthControllerProvider);
      ref.invalidate(cardSettlementStatusProvider);
    }
    return batch;
  }
}

/// What the user still has to settle for their deferred cards to count once,
/// shown with the result of an import.
///
/// Auto-disposed, so the panel reads it afresh each time it is opened: the
/// settlements it counts are confirmed from the review queue, elsewhere.
final cardSettlementStatusProvider =
    FutureProvider.autoDispose<CardSettlementStatus>(
      (ref) => ref.read(importsRepositoryProvider).cardSettlementStatus(),
    );

final importsControllerProvider =
    AsyncNotifierProvider<ImportsController, List<ImportBatch>>(
      ImportsController.new,
    );

/// The accounts the user picked to settle statements that couldn't name their
/// own destination — an ambiguous match, or a file with no readable account
/// block — keyed by the statement's `ACCTID` (`null` for that unreadable file).
///
/// Not a destination selector: it is empty on every well-formed statement, and
/// is only ever consulted when [ofxAccountDetectionProvider] came back without
/// an answer. Cleared whenever the staged file changes, so a choice made for
/// one file can never carry over to the next.
class ChosenImportAccounts extends Notifier<Map<String?, String>> {
  @override
  Map<String?, String> build() => const {};

  void select(String? statement, String? accountId) => state = {
    for (final entry in state.entries)
      if (entry.key != statement) entry.key: entry.value,
    statement: ?accountId,
  };

  void clear() => state = const {};
}

final chosenImportAccountsProvider =
    NotifierProvider<ChosenImportAccounts, Map<String?, String>>(
      ChosenImportAccounts.new,
    );

/// The file staged in the drop zone, before it is imported.
class SelectedImportFile extends Notifier<PickedImportFile?> {
  @override
  PickedImportFile? build() => null;

  void select(PickedImportFile? file) => state = file;

  void clear() => state = null;
}

final selectedImportFileProvider =
    NotifierProvider<SelectedImportFile, PickedImportFile?>(
      SelectedImportFile.new,
    );

/// The batches from the import run in this session — one per statement of the
/// file — shown in the result card.
///
/// Separate from the history list because it answers a different question —
/// "what just happened" rather than "what have I imported" — and it stays
/// empty until the user actually imports something.
class LastImportResult extends Notifier<List<ImportBatch>?> {
  @override
  List<ImportBatch>? build() => null;

  void set(List<ImportBatch>? batches) => state = batches;
}

final lastImportResultProvider =
    NotifierProvider<LastImportResult, List<ImportBatch>?>(
      LastImportResult.new,
    );
