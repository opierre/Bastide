import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../data/backup_repository.dart';
import '../domain/backup.dart';
import 'settings_controller.dart';
import 'user_data_reload.dart';

/// The extension a backup is written and read as.
const backupExtension = 'finstride';

const _typeGroup = XTypeGroup(label: 'FinStride backup', extensions: [backupExtension]);

/// Reads and writes backup files. Behind a provider so tests drive export and
/// restore without a platform channel — the same seam as `RulePackFiles`.
class BackupFiles {
  const BackupFiles();

  /// Asks where to save. Returns the path, or `null` if the user cancelled.
  Future<String?> chooseSaveLocation(String suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [_typeGroup],
    );
    return location?.path;
  }

  Future<void> write(String path, Uint8List bytes) {
    return XFile.fromData(bytes, mimeType: 'application/zip').saveTo(path);
  }

  /// Opens the native picker. Returns `null` if the user cancelled.
  Future<({String name, Uint8List bytes})?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }
}

final backupFilesProvider = Provider<BackupFiles>((ref) => const BackupFiles());

@immutable
class BackupState {
  const BackupState({
    this.isExporting = false,
    this.isPicking = false,
    this.restoreFailure,
  });

  /// State ⑥: an archive is being built and written.
  final bool isExporting;

  /// A file is being picked or inspected.
  final bool isPicking;

  /// State ⑨: why the last file picked cannot be restored. Cleared by the next
  /// pick.
  final BackupFailure? restoreFailure;

  BackupState copyWith({
    bool? isExporting,
    bool? isPicking,
    BackupFailure? restoreFailure,
    bool clearFailure = false,
  }) => BackupState(
    isExporting: isExporting ?? this.isExporting,
    isPicking: isPicking ?? this.isPicking,
    restoreFailure: clearFailure ? null : (restoreFailure ?? this.restoreFailure),
  );
}

/// Export, inspect and restore of full backups
/// (`docs/design/09-settings.md` §Sauvegarde et restauration).
///
/// A restore always goes through [pickForRestore] first: the server inspects
/// the file, so a newer-version archive is refused (⑨) before the confirmation
/// modal is even offered, let alone before any data is touched.
class BackupController extends Notifier<BackupState> {
  @override
  BackupState build() => const BackupState();

  /// Asks where to save, then builds and writes the archive. Returns its
  /// summary, or `null` if the user cancelled. Throws if either step failed.
  ///
  /// The location comes first so the button only spins for work the user has
  /// committed to, and the server only stamps a backup the user asked for.
  Future<BackupSummary?> export() async {
    if (state.isExporting) return null;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final path = await ref
        .read(backupFilesProvider)
        .chooseSaveLocation('finstride-$date.$backupExtension');
    if (path == null) return null;

    state = state.copyWith(isExporting: true);
    try {
      final export = await ref.read(backupRepositoryProvider).export();
      await ref.read(backupFilesProvider).write(_withExtension(path), export.bytes);
      ref.read(settingsControllerProvider.notifier).recordBackup(export.summary.exportedAt);
      return export.summary;
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  /// Opens the picker and has the server inspect the chosen file. Returns what
  /// the modal confirms, or `null` if the user cancelled or the file was
  /// refused — in which case [BackupState.restoreFailure] says why.
  Future<PendingRestore?> pickForRestore() async {
    state = state.copyWith(isPicking: true, clearFailure: true);
    try {
      final picked = await ref.read(backupFilesProvider).pick();
      if (picked == null) return null;
      final summary = await ref
          .read(backupRepositoryProvider)
          .inspect(picked.name, picked.bytes);
      return PendingRestore(fileName: picked.name, bytes: picked.bytes, summary: summary);
    } on ApiFailure catch (failure) {
      state = state.copyWith(restoreFailure: BackupFailure.fromCode(failure.code));
      return null;
    } catch (_) {
      state = state.copyWith(restoreFailure: BackupFailure.unknown);
      return null;
    } finally {
      state = state.copyWith(isPicking: false);
    }
  }

  /// Replaces all data with [pending]'s. Throws [BackupException] on refusal;
  /// the server rolls back, so a failure leaves the data as it was.
  Future<BackupSummary> restore(PendingRestore pending) async {
    final BackupSummary summary;
    try {
      summary = await ref
          .read(backupRepositoryProvider)
          .restore(pending.fileName, pending.bytes);
    } on ApiFailure catch (failure) {
      throw BackupException(BackupFailure.fromCode(failure.code));
    }
    _reloadEverything();
    return summary;
  }

  /// Every cached view of the user's data now describes data that no longer
  /// exists, so each one is dropped and reloads on next read.
  ///
  /// The settings go too, unlike after a reset: an archive carries the user's
  /// settings row and has just replaced it.
  void _reloadEverything() {
    reloadUserData(ref);
    ref.invalidate(settingsControllerProvider);
  }

  static String _withExtension(String path) =>
      path.toLowerCase().endsWith('.$backupExtension') ? path : '$path.$backupExtension';
}

final backupControllerProvider = NotifierProvider<BackupController, BackupState>(
  BackupController.new,
);
