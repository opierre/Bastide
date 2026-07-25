import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/account.dart';

/// Calls the `/accounts` endpoints and maps the wire JSON to domain models.
/// The only place in the accounts feature that knows the response shape —
/// see the flutter-frontend skill's data-layer rule. `ApiClient` already
/// maps the `{error:{code,message}}` envelope to [ApiFailure], so failures
/// simply propagate.
class AccountsRepository {
  AccountsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Account>> list() async {
    final json = await _apiClient.get('/accounts') as List<dynamic>;
    return json.map((entry) => _parse(entry as Map<String, dynamic>)).toList();
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    required String institution,
    required int openingBalanceMinor,
  }) async {
    final json = await _apiClient.post(
      '/accounts',
      body: {
        'name': name,
        'type': type.wireValue,
        'institution': institution,
        'opening_balance_minor': openingBalanceMinor,
      },
    );
    return _parse(json as Map<String, dynamic>);
  }

  Future<Account> update(
    String id, {
    required String name,
    required AccountType type,
    required String institution,
  }) async {
    final json = await _apiClient.patch(
      '/accounts/$id',
      body: {'name': name, 'type': type.wireValue, 'institution': institution},
    );
    return _parse(json as Map<String, dynamic>);
  }

  Future<void> archive(String id) async {
    await _apiClient.delete('/accounts/$id');
  }

  Account _parse(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AccountType.fromWire(json['type'] as String),
    institution: json['institution'] as String,
    currency: json['currency'] as String,
    openingBalanceMinor: json['opening_balance_minor'] as int,
    balanceMinor: json['balance_minor'] as int,
    archived: json['archived'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(apiClientProvider));
});
