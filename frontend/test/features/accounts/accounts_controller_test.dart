import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/accounts/application/accounts_controller.dart';
import 'package:finstride/features/accounts/domain/account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _accountJson({
  String id = 'a1',
  String name = 'Compte courant',
  String type = 'checking',
  String institution = 'BNP Paribas',
  int openingBalanceMinor = 10000,
  int balanceMinor = 10000,
}) => {
  'id': id,
  'name': name,
  'type': type,
  'institution': institution,
  'currency': 'EUR',
  'opening_balance_minor': openingBalanceMinor,
  'balance_minor': balanceMinor,
  'archived': false,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(apiClient)]);
    addTearDown(container.dispose);
  });

  test('build loads the accounts list', () async {
    when(() => apiClient.get('/accounts')).thenAnswer((_) async => [_accountJson()]);

    final accounts = await container.read(accountsControllerProvider.future);

    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Compte courant');
    expect(accounts.single.type, AccountType.checking);
  });

  test('create appends the new account on success', () async {
    when(() => apiClient.get('/accounts')).thenAnswer((_) async => <dynamic>[]);
    when(
      () => apiClient.post('/accounts', body: any(named: 'body')),
    ).thenAnswer((_) async => _accountJson(id: 'a2', name: 'Livret A', type: 'savings'));

    await container.read(accountsControllerProvider.future);
    await container
        .read(accountsControllerProvider.notifier)
        .create(
          name: 'Livret A',
          type: AccountType.savings,
          institution: 'Boursorama',
          openingBalanceMinor: 50000,
        );

    final state = container.read(accountsControllerProvider).value;
    expect(state, hasLength(1));
    expect(state!.single.id, 'a2');
  });

  test('create failure rethrows and leaves the existing list untouched', () async {
    when(() => apiClient.get('/accounts')).thenAnswer((_) async => [_accountJson()]);
    when(
      () => apiClient.post('/accounts', body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'VALIDATION_ERROR', message: 'Invalid'));

    await container.read(accountsControllerProvider.future);

    await expectLater(
      () => container
          .read(accountsControllerProvider.notifier)
          .create(name: '', type: AccountType.checking, institution: 'X', openingBalanceMinor: 0),
      throwsA(isA<ApiFailure>()),
    );

    expect(container.read(accountsControllerProvider).value, hasLength(1));
  });

  test('archive removes the account from state', () async {
    when(() => apiClient.get('/accounts')).thenAnswer((_) async => [_accountJson(id: 'a1')]);
    when(() => apiClient.delete('/accounts/a1')).thenAnswer((_) async => null);

    await container.read(accountsControllerProvider.future);
    await container.read(accountsControllerProvider.notifier).archive('a1');

    expect(container.read(accountsControllerProvider).value, isEmpty);
  });
}
