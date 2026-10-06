import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/user_settings.dart';

/// Calls `/settings` and the runtime probe at `/settings/inference/health`
/// (`PROJECT.md` §5). The only place that knows those wire shapes.
class SettingsRepository {
  SettingsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// The caller's settings, created with defaults on first read.
  Future<UserSettings> read() async {
    final json = await _apiClient.get('/settings');
    return UserSettings.fromJson(json as Map<String, dynamic>);
  }

  /// Patches the supplied fields only; omitted ones keep their stored value.
  ///
  /// A `null` argument means "not supplied" rather than "clear", which is why
  /// this takes named optionals instead of a whole [UserSettings]: sending the
  /// object back whole would overwrite a field the user edited in another
  /// debounce window with the value this screen happened to load.
  Future<UserSettings> update({
    bool? aiEnabled,
    String? inferenceBaseUrl,
    String? modelTag,
    double? confidenceThreshold,
  }) async {
    final json = await _apiClient.patch(
      '/settings',
      body: <String, Object?>{
        'ai_enabled': ?aiEnabled,
        'inference_base_url': ?inferenceBaseUrl,
        'model_tag': ?modelTag,
        'confidence_threshold': ?confidenceThreshold,
      },
    );
    return UserSettings.fromJson(json as Map<String, dynamic>);
  }

  /// Asks whether the configured runtime answers, and what it offers.
  ///
  /// Never a 5xx by contract — an absent runtime comes back as
  /// `reachable: false` on a 200 — so a thrown failure here means the *sidecar*
  /// could not be reached, not the model runtime.
  Future<InferenceHealth> probe() async {
    final json = await _apiClient.get('/settings/inference/health');
    return InferenceHealth.fromJson(json as Map<String, dynamic>);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(apiClientProvider));
});
