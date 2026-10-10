import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/local_runtime.dart';

/// Calls `/settings/inference/runtime`: the downloadable engine's status,
/// download, cancel and removal. The only place that knows those wire shapes.
class LocalRuntimeRepository {
  LocalRuntimeRepository(this._apiClient);

  final ApiClient _apiClient;

  static const _path = '/settings/inference/runtime';

  Future<LocalRuntime> read() async => _parse(await _apiClient.get(_path));

  /// Starts (or resumes) the download; the backend answers at once.
  Future<LocalRuntime> download() async =>
      _parse(await _apiClient.post('$_path/download'));

  /// Stops the download, keeping what it fetched for the next one.
  Future<LocalRuntime> cancel() async =>
      _parse(await _apiClient.post('$_path/cancel'));

  /// Deletes the engine and its model from disk.
  Future<LocalRuntime> remove() async => _parse(await _apiClient.delete(_path));

  LocalRuntime _parse(Object? json) =>
      LocalRuntime.fromJson(json as Map<String, dynamic>);
}

final localRuntimeRepositoryProvider = Provider<LocalRuntimeRepository>((ref) {
  return LocalRuntimeRepository(ref.watch(apiClientProvider));
});
