import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rule_packs_repository.dart';
import '../domain/rule_pack.dart';
import 'recategorized_reload.dart';
import 'rules_controller.dart';

/// The extension a pack is written and read as.
const rulePackExtension = 'json';

/// Reads and writes pack files. Behind an interface so widget tests can drive
/// import and export without a platform channel — see the testing skill.
class RulePackFiles {
  const RulePackFiles();

  /// Opens the native picker and returns the file's text, or `null` if the
  /// user cancelled.
  Future<String?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Bastide rule pack', extensions: [rulePackExtension]),
      ],
    );
    return file?.readAsString();
  }

  /// Asks where to save and writes [contents]. Returns the chosen path, or
  /// `null` if the user cancelled.
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return null;
    final file = XFile.fromData(
      utf8.encode(contents),
      mimeType: 'application/json',
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return location.path;
  }
}

final rulePackFilesProvider = Provider<RulePackFiles>(
  (ref) => const RulePackFiles(),
);

/// The packs bundled with the app, offered where a user has no rules at all.
final builtinPacksProvider = FutureProvider<List<BuiltinPack>>((ref) {
  return ref.read(rulePacksRepositoryProvider).listBuiltin();
});

/// A pack the user has chosen but not yet imported: where it came from, and
/// what importing it would do.
///
/// The two travel together because the confirmation sheet needs both — the
/// report to decide on, and the source to then import *the same thing*. A
/// sheet that previewed one source and imported another would report numbers
/// that never applied to what it wrote.
@immutable
class PendingRulePack {
  const PendingRulePack({required this.preview, this.pack, this.builtinId});

  final RulePackPreview preview;
  final RulePack? pack;
  final String? builtinId;
}

/// Import and export of rule packs.
///
/// Nothing here writes without a preview first: the import sheet always shows
/// what a pack would do, and export always shows its contents. Both steps exist
/// for the same reason — a pack is a file that crosses between people, and the
/// user is entitled to read it in each direction.
class RulePacksController extends Notifier<void> {
  @override
  void build() {}

  /// Opens the file picker and reports what the chosen pack would do.
  ///
  /// Returns `null` when the user cancelled. Throws [RulePackRejected] when the
  /// file isn't a pack this build reads — the sheet renders the reason.
  Future<PendingRulePack?> pickForImport() async {
    final source = await ref.read(rulePackFilesProvider).pick();
    if (source == null) return null;

    final pack = parseRulePack(source);
    final preview = await ref
        .read(rulePacksRepositoryProvider)
        .preview(pack: pack);
    return PendingRulePack(preview: preview, pack: pack);
  }

  /// The same report for one of the bundled packs, which needs no file.
  Future<PendingRulePack> previewBuiltin(String builtinId) async {
    final preview = await ref
        .read(rulePacksRepositoryProvider)
        .preview(builtinId: builtinId);
    return PendingRulePack(preview: preview, builtinId: builtinId);
  }

  /// Imports a pack the user has seen the report for.
  ///
  /// The rules list is reloaded rather than patched: an import creates several
  /// rules at once and renumbers nothing, so the server's ordering is the only
  /// truthful one to show next. An import that also applied the pack has
  /// rewritten categories across the app, so those views are reloaded too.
  Future<RulePackImportResult> import(
    PendingRulePack pending, {
    bool applyNow = false,
  }) async {
    final result = await ref
        .read(rulePacksRepositoryProvider)
        .import(
          pack: pending.pack,
          builtinId: pending.builtinId,
          applyNow: applyNow,
        );
    ref.invalidate(rulesControllerProvider);
    if (result.recategorizedCount > 0) await reloadRecategorizedViews(ref);
    return result;
  }

  /// Builds the pack the user will review before saving.
  Future<RulePackExport> prepareExport({
    bool enabledOnly = false,
    String? name,
  }) {
    return ref
        .read(rulePacksRepositoryProvider)
        .export(enabledOnly: enabledOnly, name: name);
  }

  /// Writes a reviewed pack to disk. Returns the path, or `null` on cancel.
  Future<String?> saveExport(RulePack pack) {
    return ref
        .read(rulePackFilesProvider)
        .save(
          suggestedName: '${_fileSafe(pack.name)}.$rulePackExtension',
          contents: pack.toPrettyJson(),
        );
  }

  /// A pack name can hold anything the user typed; a filename cannot.
  static String _fileSafe(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
    return cleaned.isEmpty ? 'bastide-rules' : cleaned.replaceAll(' ', '-');
  }
}

final rulePacksControllerProvider = NotifierProvider<RulePacksController, void>(
  RulePacksController.new,
);
