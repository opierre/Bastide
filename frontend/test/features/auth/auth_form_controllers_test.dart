import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/storage/token_store.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/application/auth_form_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockTokenStore extends Mock implements TokenStore {}

Map<String, dynamic> _userJson() => {
  'id': 'u1',
  'email': 'ada@example.com',
  'display_name': 'Ada',
  'locale': 'fr',
  'currency': 'EUR',
};

const _invalidCredentials = ApiFailure(
  code: 'INVALID_CREDENTIALS',
  message: 'Incorrect identifier or password.',
);

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

  /// Keeps an auto-disposed provider alive for the test's duration.
  void keepAlive(ProviderListenable<Object?> provider) {
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
  }

  Future<void> register() => container
      .read(registerControllerProvider.notifier)
      .submit(
        email: 'ada@example.com',
        password: 'correct-horse-7',
        displayName: 'ada.lovelace',
        locale: 'fr',
        currency: 'EUR',
      );

  group('LoginController', () {
    test('success starts the session', () async {
      keepAlive(loginControllerProvider);
      when(
        () => apiClient.post('/auth/login', body: any(named: 'body')),
      ).thenAnswer((_) async => {'token': 'tok-1', 'user': _userJson()});

      await container.read(authControllerProvider.future);
      await container
          .read(loginControllerProvider.notifier)
          .submit(identifier: 'ada@example.com', password: 'secret');

      expect(container.read(loginControllerProvider).hasError, isFalse);
      expect(
        container.read(authControllerProvider).value?.email,
        'ada@example.com',
      );
      expect(container.read(authTokenProvider), 'tok-1');
      verify(() => tokenStore.write('tok-1')).called(1);
      verify(
        () => apiClient.post(
          '/auth/login',
          body: {'identifier': 'ada@example.com', 'password': 'secret'},
        ),
      ).called(1);
    });

    test('a rejected pair errors the form, not the session', () async {
      keepAlive(loginControllerProvider);
      when(
        () => apiClient.post('/auth/login', body: any(named: 'body')),
      ).thenThrow(_invalidCredentials);

      await container.read(authControllerProvider.future);
      await container
          .read(loginControllerProvider.notifier)
          .submit(identifier: 'ada@example.com', password: 'wrong');

      final form = container.read(loginControllerProvider);
      expect((form.error as ApiFailure?)?.code, 'INVALID_CREDENTIALS');
      final session = container.read(authControllerProvider);
      expect(session.hasError, isFalse);
      expect(session.value, isNull);
      expect(container.read(authTokenProvider), isNull);
      verifyNever(() => tokenStore.write(any()));
    });
  });

  group('RegisterController', () {
    test(
      'a failed login leaves no error for the registration form (#319)',
      () async {
        keepAlive(loginControllerProvider);
        keepAlive(registerControllerProvider);
        when(
          () => apiClient.post('/auth/login', body: any(named: 'body')),
        ).thenThrow(_invalidCredentials);
        when(
          () => apiClient.post('/auth/register', body: any(named: 'body')),
        ).thenAnswer(
          (_) async => {
            'token': 'tok-2',
            'user': _userJson(),
            'recovery_code': 'ABCD-EFGH-IJKL-MNOP',
          },
        );

        await container.read(authControllerProvider.future);
        await container
            .read(loginControllerProvider.notifier)
            .submit(identifier: 'ada@example.com', password: 'wrong');
        expect(container.read(registerControllerProvider).hasError, isFalse);

        await register();

        expect(container.read(registerControllerProvider).hasError, isFalse);
        expect(container.read(authControllerProvider).value, isNotNull);
        expect(
          container.read(pendingRecoveryCodeProvider),
          'ABCD-EFGH-IJKL-MNOP',
        );
      },
    );

    test('a failure errors the form and leaves the user signed out', () async {
      keepAlive(registerControllerProvider);
      when(
        () => apiClient.post('/auth/register', body: any(named: 'body')),
      ).thenThrow(const ApiFailure(code: 'EMAIL_TAKEN', message: 'taken'));

      await container.read(authControllerProvider.future);
      await register();

      final form = container.read(registerControllerProvider);
      expect((form.error as ApiFailure?)?.code, 'EMAIL_TAKEN');
      expect(container.read(authControllerProvider).hasError, isFalse);
      expect(container.read(authControllerProvider).value, isNull);
    });

    for (final (code, owner, other) in [
      ('EMAIL_TAKEN', RegisterField.email, RegisterField.displayName),
      ('DISPLAY_NAME_TAKEN', RegisterField.displayName, RegisterField.email),
    ]) {
      test('$code clears only when its own field is edited', () async {
        keepAlive(registerControllerProvider);
        when(
          () => apiClient.post('/auth/register', body: any(named: 'body')),
        ).thenThrow(ApiFailure(code: code, message: 'taken'));
        await register();
        final notifier = container.read(registerControllerProvider.notifier);

        notifier.fieldEdited(other);
        expect(container.read(registerControllerProvider).hasError, isTrue);

        notifier.fieldEdited(owner);
        expect(container.read(registerControllerProvider).hasError, isFalse);
      });
    }

    test('an error with no field clears on any edit', () async {
      keepAlive(registerControllerProvider);
      when(
        () => apiClient.post('/auth/register', body: any(named: 'body')),
      ).thenThrow(const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom'));
      await register();

      container
          .read(registerControllerProvider.notifier)
          .fieldEdited(RegisterField.password);

      expect(container.read(registerControllerProvider).hasError, isFalse);
    });
  });
}
