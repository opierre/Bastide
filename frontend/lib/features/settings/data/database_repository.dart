import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/database_reset.dart';

/// Calls `/database`. The only place that knows its
/// wire shapes.
class DatabaseRepository {
  DatabaseRepository(this._apiClient);

  final ApiClient _apiClient;

  /// How many rows this profile holds, read fresh each time the confirmation is
  /// shown — the modal states counts, so they must not be a cached claim.
  Future<DatabaseCounts> summary() => _counts('/database/summary', post: false);

  /// Deletes everything this profile owns, and reports what went.
  Future<DatabaseCounts> reset() => _counts('/database/reset', post: true);

  Future<DatabaseCounts> _counts(String path, {required bool post}) async {
    final json =
        await (post ? _apiClient.post(path) : _apiClient.get(path))
            as Map<String, dynamic>;
    return DatabaseCounts.fromJson(json['counts'] as Map<String, dynamic>);
  }
}

final databaseRepositoryProvider = Provider<DatabaseRepository>((ref) {
  return DatabaseRepository(ref.watch(apiClientProvider));
});
