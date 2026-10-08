import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/storage/token_store.dart';
import 'package:finstride/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockTokenStore extends Mock implements TokenStore {}

Map<String, dynamic> _userJson({String email = 'ada@example.com'}) => {
  'id': 'u1',
  'email': email,
  'display_name': 'Ada',
  'locale': 'fr',
  'currency': 'EUR',
};

void main() {
  late MockApiClient apiClient;
  late MockTokenStore tokenStore;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    apiClient = MockApiClient();
    tokenStore = MockTokenStore();
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    when(() => tokenStore.write(any())).thenAnswer((_) async {});
    when(() => tokenStore.delete()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        tokenStoreProvider.overrideWithValue(tokenStore),
      ],
    );
    addTearDown(container.dispose);
  });

  test('build restores no session when no token is stored', () async {
    final user = await container.read(authControllerProvider.future);

    expect(user, isNull);
    verifyNever(() => apiClient.get(any()));
  });

  test('build restores the session via me() when a token is stored', () async {
    when(() => tokenStore.read()).thenAnswer((_) async => 'stored-token');
    when(
      () => apiClient.get('/auth/me'),
    ).thenAnswer((_) async => {'user': _userJson()});

    final user = await container.read(authControllerProvider.future);

    expect(user?.email, 'ada@example.com');
    expect(container.read(authTokenProvider), 'stored-token');
  });

  test('login success transitions to the authenticated state', () async {
    when(
      () => apiClient.post('/auth/login', body: any(named: 'body')),
    ).thenAnswer((_) async => {'token': 'tok-1', 'user': _userJson()});

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ada@example.com', password: 'secret');

    final state = container.read(authControllerProvider);
    expect(state.value?.email, 'ada@example.com');
    expect(container.read(authTokenProvider), 'tok-1');
    verify(() => tokenStore.write('tok-1')).called(1);
  });

  test('login failure surfaces an error state and stores no token', () async {
    when(
      () => apiClient.post('/auth/login', body: any(named: 'body')),
    ).thenThrow(
      const ApiFailure(
        code: 'INVALID_CREDENTIALS',
        message: 'Incorrect email or password.',
      ),
    );

    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ada@example.com', password: 'wrong');

    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect((state.error as ApiFailure).code, 'INVALID_CREDENTIALS');
    expect(container.read(authTokenProvider), isNull);
    verifyNever(() => tokenStore.write(any()));
  });

  test(
    'logout clears the stored token and resets state to signed out',
    () async {
      when(() => tokenStore.read()).thenAnswer((_) async => 'existing-token');
      when(
        () => apiClient.get('/auth/me'),
      ).thenAnswer((_) async => {'user': _userJson()});
      when(() => apiClient.post('/auth/logout')).thenAnswer((_) async => null);

      await container.read(authControllerProvider.future);
      expect(container.read(authControllerProvider).value, isNotNull);

      await container.read(authControllerProvider.notifier).logout();

      expect(container.read(authControllerProvider).value, isNull);
      expect(container.read(authTokenProvider), isNull);
      verify(() => tokenStore.delete()).called(1);
      verify(() => apiClient.post('/auth/logout')).called(1);
    },
  );
}
