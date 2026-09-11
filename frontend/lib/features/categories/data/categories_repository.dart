import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/category.dart';

/// Calls `/categories` and maps the wire JSON to [AppCategory].
///
/// `PATCH` and `DELETE` are offered for every category, system ones included:
/// the API 404s a system category because it isn't user-owned, and that refusal
/// is the guarantee — the lock glyph in the UI only *states* it. A repository
/// that filtered those calls out client-side would hide whether the guarantee
/// exists at all.
class CategoriesRepository {
  CategoriesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppCategory>> list() async {
    final json = await _apiClient.get('/categories') as List<dynamic>;
    return json
        .map((entry) => AppCategory.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<AppCategory> create({
    required String name,
    required String kind,
    required String icon,
    required String color,
    String? parentId,
  }) async {
    final json = await _apiClient.post(
      '/categories',
      body: {
        'name': name,
        'kind': kind,
        'icon': icon,
        'color': color,
        'parent_id': parentId,
      },
    );
    return AppCategory.fromJson(json as Map<String, dynamic>);
  }

  Future<AppCategory> update(
    String id, {
    String? name,
    String? kind,
    String? icon,
    String? color,
    String? parentId,
    bool clearParent = false,
  }) async {
    final json = await _apiClient.patch(
      '/categories/$id',
      body: {
        'name': ?name,
        'kind': ?kind,
        'icon': ?icon,
        'color': ?color,
        if (clearParent) 'parent_id': null else 'parent_id': ?parentId,
      },
    );
    return AppCategory.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _apiClient.delete('/categories/$id');
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(apiClientProvider));
});
