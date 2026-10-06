import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/rule_pack.dart';

/// Calls `/rules/packs`.
///
/// Every method takes a pack *source* — an uploaded document or a bundled id —
/// exactly as `RulePackSource` defines it, so the confirmation sheet can
/// preview and then import the same thing without the caller reshaping it.
class RulePacksRepository {
  RulePacksRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BuiltinPack>> listBuiltin() async {
    final json = await _apiClient.get('/rules/packs/builtin') as List<dynamic>;
    return json
        .map((entry) => BuiltinPack.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<RulePackPreview> preview({RulePack? pack, String? builtinId}) async {
    final json =
        await _apiClient.post(
              '/rules/packs/preview',
              body: _source(pack, builtinId),
            )
            as Map<String, dynamic>;
    return RulePackPreview.fromJson(json);
  }

  Future<RulePackImportResult> import({
    RulePack? pack,
    String? builtinId,
    bool applyNow = false,
  }) async {
    final json =
        await _apiClient.post(
              '/rules/packs/import',
              body: {..._source(pack, builtinId), 'apply_now': applyNow},
            )
            as Map<String, dynamic>;
    return RulePackImportResult.fromJson(json);
  }

  /// The caller's rules as a pack, for review. A body rather than a download:
  /// a pattern can hold personal detail — « VIR SALAIRE DUPONT » — so the user
  /// sees the contents before they become a file.
  Future<RulePackExport> export({
    bool enabledOnly = false,
    String? name,
  }) async {
    final json =
        await _apiClient.get(
              '/rules/packs/export',
              query: {'enabled_only': '$enabledOnly', 'name': ?name},
            )
            as Map<String, dynamic>;
    return RulePackExport.fromJson(json);
  }

  Map<String, dynamic> _source(RulePack? pack, String? builtinId) {
    assert(
      (pack == null) != (builtinId == null),
      'Provide exactly one of pack or builtinId.',
    );
    return {'pack': ?pack?.toJson(), 'builtin_id': ?builtinId};
  }
}

final rulePacksRepositoryProvider = Provider<RulePacksRepository>((ref) {
  return RulePacksRepository(ref.watch(apiClientProvider));
});
