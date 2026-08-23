import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/rule.dart';

/// Calls `/rules` and maps the wire JSON to domain models.
class RulesRepository {
  RulesRepository(this._apiClient);

  final ApiClient _apiClient;

  /// The caller's rules, already in priority order server-side.
  Future<List<Rule>> list() async {
    final json = await _apiClient.get('/rules') as List<dynamic>;
    return json.map((entry) => Rule.fromJson(entry as Map<String, dynamic>)).toList();
  }

  Future<Rule> create({
    required int priority,
    required RuleMatchField matchField,
    required RuleMatchType matchType,
    required String pattern,
    required String categoryId,
    required bool enabled,
  }) async {
    final json = await _apiClient.post(
      '/rules',
      body: {
        'priority': priority,
        'match_field': matchField.wire,
        'match_type': matchType.wire,
        'pattern': pattern,
        'category_id': categoryId,
        'enabled': enabled,
      },
    );
    return Rule.fromJson(json as Map<String, dynamic>);
  }

  Future<Rule> update(
    String id, {
    int? priority,
    RuleMatchField? matchField,
    RuleMatchType? matchType,
    String? pattern,
    String? categoryId,
    bool? enabled,
  }) async {
    final json = await _apiClient.patch(
      '/rules/$id',
      body: {
        'priority': ?priority,
        'match_field': ?matchField?.wire,
        'match_type': ?matchType?.wire,
        'pattern': ?pattern,
        'category_id': ?categoryId,
        'enabled': ?enabled,
      },
    );
    return Rule.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _apiClient.delete('/rules/$id');

  /// Re-runs the enabled rules over existing transactions, returning how many
  /// they actually recategorized. Rows the user categorized by hand are never
  /// touched — that promise is the backend's, and the toast repeats it.
  Future<int> apply({String? accountId}) async {
    final json =
        await _apiClient.post('/rules/apply', body: {'account_id': accountId})
            as Map<String, dynamic>;
    return json['recategorized_count'] as int;
  }

  /// The form's pre-fill for a rule derived from [transactionId].
  Future<RuleSuggestion> suggestion(String transactionId) async {
    final json = await _apiClient.get(
      '/rules/suggestion',
      query: {'transaction_id': transactionId},
    );
    return RuleSuggestion.fromJson(json as Map<String, dynamic>);
  }

  /// Turns a correction into a rule in one call.
  ///
  /// One endpoint rather than a flag on the transaction patch: this both fixes
  /// the row *and* may recategorize many others, and the response has to report
  /// that second count (PROJECT.md §5b).
  Future<RuleFromTransactionResult> createFromTransaction({
    required String transactionId,
    required RuleMatchField matchField,
    required RuleMatchType matchType,
    required String pattern,
    required String categoryId,
    required bool applyNow,
  }) async {
    final json =
        await _apiClient.post(
              '/rules/from-transaction',
              body: {
                'transaction_id': transactionId,
                'match_field': matchField.wire,
                'match_type': matchType.wire,
                'pattern': pattern,
                'category_id': categoryId,
                'apply_now': applyNow,
              },
            )
            as Map<String, dynamic>;
    return RuleFromTransactionResult(
      rule: Rule.fromJson(json['rule'] as Map<String, dynamic>),
      recategorizedCount: json['recategorized_count'] as int,
    );
  }

  /// Counts what an *unsaved* condition would match, with up to three examples.
  ///
  /// Throws [ApiFailure] with code `RULE_PATTERN_INVALID` when a `regex`
  /// pattern doesn't compile — which is a different answer from a count of
  /// zero, and the editor renders it on the pattern field rather than as one.
  Future<RulePreview> preview({
    required RuleMatchField matchField,
    required RuleMatchType matchType,
    required String pattern,
  }) async {
    final json =
        await _apiClient.post(
              '/rules/preview',
              body: {
                'match_field': matchField.wire,
                'match_type': matchType.wire,
                'pattern': pattern,
              },
            )
            as Map<String, dynamic>;
    return RulePreview(
      matchCount: json['match_count'] as int,
      samples: (json['samples'] as List<dynamic>)
          .map((entry) => RuleSample.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}

final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  return RulesRepository(ref.watch(apiClientProvider));
});
