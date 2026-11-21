import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/accounts_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../networth/application/networth_controller.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/application/review_count_provider.dart';
import '../data/imports_repository.dart';
import '../../accounts/application/settlement_rule_controller.dart';
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

/// The account the import history is narrowed to, named so the filter can
/// say which without waiting for the accounts list.
@immutable
class ImportHistoryAccountFilter {
  const ImportHistoryAccountFilter({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportHistoryAccountFilter &&
          other.id == id &&
          other.name == name);

  @override
  int get hashCode => Object.hash(id, name);
}

/// The account filter of the import history: set from the account detail's
/// « dernier import » link, lifted by the filter's `x`.
class ImportHistoryAccount extends Notifier<ImportHistoryAccountFilter?> {
  @override
  ImportHistoryAccountFilter? build() => null;

  void show(ImportHistoryAccountFilter account) => state = account;

  void clear() => state = null;
}

final importHistoryAccountProvider =
    NotifierProvider<ImportHistoryAccount, ImportHistoryAccountFilter?>(
      ImportHistoryAccount.new,
    );

/// Import history, most recent first, and the import action itself.
///
/// A successful import prepends its batch instead of refetching: the response
/// *is* the new history entry, so a second round trip would only re-read what
/// we already hold. Failures propagate to the caller rather than replacing
/// `state` — a rejected file shouldn't blank out the history behind it.
class ImportsController extends AsyncNotifier<List<ImportBatch>> {
  /// Rebuilds from the API whenever [importHistoryAccountProvider] changes.
  @override
  Future<List<ImportBatch>> build() => ref
      .read(importsRepositoryProvider)
      .listBatches(accountId: ref.watch(importHistoryAccountProvider)?.id);

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(importsRepositoryProvider)
          .listBatches(accountId: ref.read(importHistoryAccountProvider)?.id),
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

    final filter = ref.read(importHistoryAccountProvider);
    if (filter != null && filter.id != batch.accountId) {
      // The history is narrowed to another account, where the new batch would
      // not show: lift the filter, which refetches the whole history with it.
      ref.read(importHistoryAccountProvider.notifier).clear();
    } else {
      // Re-importing an identical file returns the original batch rather than a
      // new one, so replace a matching entry instead of listing it twice.
      final history = state.value ?? const <ImportBatch>[];
      state = AsyncValue.data([
        batch,
        ...history.where((existing) => existing.id != batch.id),
      ]);
    }

    // An import writes rows and moves the account's balance, so every panel reading
    // either is stale the moment it lands — without this, the transactions list only
    // caught up on a restart. Invalidated rather than refetched here: the panels that
    // are actually being watched reload themselves, the ones that aren't stay idle.
    // A `failed` batch wrote nothing, so it leaves them alone.
    if (batch.status != ImportStatus.failed) {
      ref.invalidate(transactionsControllerProvider);
      ref.invalidate(reviewCountProvider);
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

/// The batches imported in this session, newest first.
///
/// Separate from the history list because it answers a different question —
/// "did the user just import something" — which is what the card-settlement
/// warnings wait for: they qualify an import's result and stay hidden until
/// one has run.
class LastImportResult extends Notifier<List<ImportBatch>?> {
  @override
  List<ImportBatch>? build() => null;

  void set(List<ImportBatch>? batches) => state = batches;

  void add(ImportBatch batch) => state = [batch, ...?state];
}

final lastImportResultProvider =
    NotifierProvider<LastImportResult, List<ImportBatch>?>(
      LastImportResult.new,
    );

/// How long a freshly imported batch stays highlighted at the top of the
/// history (`docs/design/06-imports.md`).
const importHighlightDuration = Duration(seconds: 4);

/// The history rows to highlight: batches imported in the last few seconds,
/// so the user sees where the file they just imported went.
class RecentImportHighlights extends Notifier<Set<String>> {
  final _timers = <String, Timer>{};

  @override
  Set<String> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  void mark(String batchId) {
    _timers.remove(batchId)?.cancel();
    state = {...state, batchId};
    _timers[batchId] = Timer(importHighlightDuration, () {
      _timers.remove(batchId);
      state = {...state}..remove(batchId);
    });
  }
}

final recentImportHighlightsProvider =
    NotifierProvider<RecentImportHighlights, Set<String>>(
      RecentImportHighlights.new,
    );
