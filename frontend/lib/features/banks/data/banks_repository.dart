import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';

/// Resolves a French bank code (`code banque`, the OFX `BANKID`) to the bank
/// that carries it, against the backend's directory.
///
/// The directory lives on the backend rather than here because it is reference
/// data that goes stale as banks merge — one place to correct it, and the
/// frontend stays a reader of it.
class BanksRepository {
  BanksRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Answers per code within a session. The directory is static, and a
  /// statement is re-read on every re-stage of the same file.
  final _cache = <String, String?>{};

  /// The bank behind [bankCode], or `null` when we can't name it — an unknown
  /// code, or a lookup that failed. Never throws: naming the bank is a
  /// courtesy, and losing it must not cost the user their import.
  Future<String?> nameForCode(String bankCode) async {
    final code = bankCode.trim();
    if (code.isEmpty) return null;
    if (_cache.containsKey(code)) return _cache[code];

    String? name;
    try {
      final json =
          await _apiClient.get('/banks', query: {'bank_code': code})
              as List<dynamic>;
      if (json.isNotEmpty) {
        name = (json.first as Map<String, dynamic>)['name'] as String?;
      }
    } on ApiFailure {
      return null;
    } catch (_) {
      return null;
    }

    _cache[code] = name;
    return name;
  }
}

final banksRepositoryProvider = Provider<BanksRepository>((ref) {
  return BanksRepository(ref.watch(apiClientProvider));
});
