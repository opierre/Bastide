import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/categorization_run.dart';

/// Calls `/categorization/runs` and, for the availability check, `/settings`
/// and `/settings/inference/health`.
///
/// The two settings calls live here rather than in a settings repository for
/// the reason `TransactionsRepository` reaches for `/categories`: they serve an
/// affordance that belongs to *this* feature — whether to show any stage-2 UI
/// at all — and the settings panel that owns those endpoints holds state this
/// feature never renders.
class CategorizationRepository {
  CategorizationRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Starts a run and returns it immediately (202). Asking while one is in
  /// flight returns that run instead of starting a second — one run at a time
  /// per user (PROJECT.md §7), so the caller polls whatever comes back.
  Future<CategorizationRun> startRun({String? accountId, required RunScope scope}) async {
    final json = await _apiClient.post(
      '/categorization/runs',
      body: {'account_id': accountId, 'scope': scope.wire},
    );
    return CategorizationRun.fromJson(json as Map<String, dynamic>);
  }

  /// The progress poll.
  Future<CategorizationRun> getRun(String id) async {
    final json = await _apiClient.get('/categorization/runs/$id');
    return CategorizationRun.fromJson(json as Map<String, dynamic>);
  }

  /// Cancels an in-flight run; the executor stops after the batch it is on.
  Future<CategorizationRun> cancelRun(String id) async {
    final json = await _apiClient.post('/categorization/runs/$id/cancel');
    return CategorizationRun.fromJson(json as Map<String, dynamic>);
  }

  /// Whether stage 2 has anything to offer right now.
  ///
  /// The health probe is skipped when the user has not opted in: an absent
  /// runtime is the expected default state, and pinging for one the user
  /// never asked for costs a round trip to learn nothing.
  Future<AiAvailability> readAvailability() async {
    final settings = await _apiClient.get('/settings') as Map<String, dynamic>;
    final enabled = settings['ai_enabled'] as bool;
    if (!enabled) return AiAvailability.unavailable;

    final health = await _apiClient.get('/settings/inference/health') as Map<String, dynamic>;
    return AiAvailability(enabled: true, reachable: health['reachable'] as bool);
  }
}

final categorizationRepositoryProvider = Provider<CategorizationRepository>((ref) {
  return CategorizationRepository(ref.watch(apiClientProvider));
});
