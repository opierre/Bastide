import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/router/app_router.dart';
import 'package:bastide/core/storage/token_store.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/presentation/forgot_password_screen.dart';
import 'package:bastide/features/auth/presentation/recovery_code_card.dart';
import 'package:bastide/features/auth/presentation/recovery_code_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockTokenStore extends Mock implements TokenStore {}

const _code = '7K2M-QX9D-4HPA-T0RV-8ZNC';
const _newCode = 'B3WE-9FJS-K2XQ-M7PD-1RNA';
const _strongPassword = 'Nouveau-mot-2-passe';

Map<String, dynamic> _sessionJson({String code = _code}) => {
  'token': 'tok-1',
  'user': {
    'id': 'u1',
    'email': 'ada@example.com',
    'display_name': 'Ada',
    'locale': 'fr',
    'currency': 'EUR',
  },
  'recovery_code': code,
};

void main() {
  late _MockApiClient apiClient;
  late _MockTokenStore tokenStore;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = _MockApiClient();
    tokenStore = _MockTokenStore();
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

  Widget wrap(Widget child, {Locale locale = const Locale('fr')}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: appDarkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('controller', () {
    test('register leaves the issued code pending', () async {
      when(
        () => apiClient.post('/auth/register', body: any(named: 'body')),
      ).thenAnswer((_) async => _sessionJson());

      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .register(
            email: 'ada@example.com',
            password: _strongPassword,
            displayName: 'Ada',
            locale: 'fr',
            currency: 'EUR',
          );

      expect(container.read(authControllerProvider).value?.id, 'u1');
      expect(container.read(pendingRecoveryCodeProvider), _code);
    });

    test('login leaves no code pending', () async {
      when(
        () => apiClient.post('/auth/login', body: any(named: 'body')),
      ).thenAnswer((_) async => {..._sessionJson()}..remove('recovery_code'));

      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(identifier: 'ada@example.com', password: 'secret');

      expect(container.read(pendingRecoveryCodeProvider), isNull);
    });
  });

  group('forgot password screen', () {
    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('resetIdentifierField')),
        'ada@example.com',
      );
      await tester.enterText(find.byKey(const Key('resetCodeField')), _code);
      await tester.enterText(
        find.byKey(const Key('resetPasswordField')),
        _strongPassword,
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('resetSubmitButton')));
      await tester.tap(find.byKey(const Key('resetSubmitButton')));
      await tester.pumpAndSettle();
    }

    testWidgets('a matching code signs in with the replacement code pending', (
      tester,
    ) async {
      when(
        () => apiClient.post('/auth/password-reset', body: any(named: 'body')),
      ).thenAnswer((_) async => _sessionJson(code: _newCode));
      await tester.pumpWidget(wrap(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await fillAndSubmit(tester);

      verify(
        () => apiClient.post(
          '/auth/password-reset',
          body: {
            'identifier': 'ada@example.com',
            'recovery_code': _code,
            'new_password': _strongPassword,
          },
        ),
      ).called(1);
      expect(container.read(authControllerProvider).value?.id, 'u1');
      expect(container.read(pendingRecoveryCodeProvider), _newCode);
      verify(() => tokenStore.write('tok-1')).called(1);
    });

    testWidgets('a wrong code banners on the form, not the session', (
      tester,
    ) async {
      when(
        () => apiClient.post('/auth/password-reset', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'INVALID_RECOVERY_CODE', message: 'nope'),
      );
      await tester.pumpWidget(wrap(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await fillAndSubmit(tester);

      expect(find.byKey(const Key('resetErrorText')), findsOneWidget);
      expect(
        find.text(
          'Identifiant ou code de récupération incorrect. Vérifiez le code et réessayez.',
        ),
        findsOneWidget,
      );
      expect(container.read(authControllerProvider).hasError, isFalse);
      expect(container.read(pendingRecoveryCodeProvider), isNull);
    });

    testWidgets('a weak new password keeps the submit disabled', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('resetPasswordField')),
        'abc',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('resetSubmitButton')));
      await tester.tap(find.byKey(const Key('resetSubmitButton')));
      await tester.pumpAndSettle();

      verifyNever(() => apiClient.post(any(), body: any(named: 'body')));
    });

    testWidgets('renders in English', (tester) async {
      await tester.pumpWidget(
        wrap(const ForgotPasswordScreen(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Reset your password with your recovery code.'),
        findsOneWidget,
      );
      expect(find.text('Back to sign in'), findsOneWidget);
    });
  });

  group('recovery code screen', () {
    testWidgets('continue stays disabled until the code is acknowledged', (
      tester,
    ) async {
      container.read(pendingRecoveryCodeProvider.notifier).show(_code);
      await tester.pumpWidget(wrap(const RecoveryCodeScreen()));
      await tester.pumpAndSettle();

      expect(find.text(_code), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('recoveryCodeContinueButton')),
      );
      await tester.tap(find.byKey(const Key('recoveryCodeContinueButton')));
      await tester.pump();
      expect(container.read(pendingRecoveryCodeProvider), _code);

      await tester.ensureVisible(
        find.byKey(const Key('recoveryCodeAcknowledge')),
      );
      await tester.tap(find.byKey(const Key('recoveryCodeAcknowledge')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('recoveryCodeContinueButton')),
      );
      await tester.tap(find.byKey(const Key('recoveryCodeContinueButton')));
      await tester.pump();

      expect(container.read(pendingRecoveryCodeProvider), isNull);
    });

    testWidgets('renders in English', (tester) async {
      container.read(pendingRecoveryCodeProvider.notifier).show(_code);
      await tester.pumpWidget(
        wrap(const RecoveryCodeScreen(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep your recovery code'), findsOneWidget);
      expect(find.text("I've kept this code somewhere safe"), findsOneWidget);
    });
  });

  group('router', () {
    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: const Locale('fr'),
            theme: appDarkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('the forgot-password screen is reachable signed out', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      await tester.tap(find.byKey(const Key('goToForgotPasswordButton')));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        ForgotPasswordScreen.path,
      );
    });

    testWidgets('a pending code holds the new session on its screen', (
      tester,
    ) async {
      when(
        () => apiClient.post('/auth/password-reset', body: any(named: 'body')),
      ).thenAnswer((_) async => _sessionJson(code: _newCode));
      final router = await pumpRouter(tester);
      router.go(ForgotPasswordScreen.path);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('resetIdentifierField')),
        'ada@example.com',
      );
      await tester.enterText(find.byKey(const Key('resetCodeField')), _code);
      await tester.enterText(
        find.byKey(const Key('resetPasswordField')),
        _strongPassword,
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('resetSubmitButton')));
      await tester.tap(find.byKey(const Key('resetSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryCodeScreen), findsOneWidget);
      expect(find.text(_newCode), findsOneWidget);

      // Trying to leave without acknowledging lands back on the code.
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryCodeScreen), findsOneWidget);
    });
  });

  group('settings regeneration modal', () {
    Future<void> openAndSubmit(WidgetTester tester, String password) async {
      await tester.pumpWidget(wrap(const RecoveryCodeCard()));
      await tester.tap(find.byKey(const Key('settingsRecoveryButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recoveryModalPasswordField')),
        password,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('recoveryModalGenerate')));
      await tester.pumpAndSettle();
    }

    testWidgets('the right password shows the new code once', (tester) async {
      when(
        () => apiClient.post('/auth/recovery-code', body: any(named: 'body')),
      ).thenAnswer((_) async => {'recovery_code': _newCode});

      await openAndSubmit(tester, 'secret');

      verify(
        () =>
            apiClient.post('/auth/recovery-code', body: {'password': 'secret'}),
      ).called(1);
      expect(find.text(_newCode), findsOneWidget);

      await tester.tap(find.byKey(const Key('recoveryModalDone')));
      await tester.pumpAndSettle();
      expect(find.text(_newCode), findsNothing);
    });

    testWidgets('a wrong password banners and keeps the form', (tester) async {
      when(
        () => apiClient.post('/auth/recovery-code', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'INVALID_CREDENTIALS', message: 'nope'),
      );

      await openAndSubmit(tester, 'wrong');

      expect(find.byKey(const Key('recoveryModalError')), findsOneWidget);
      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      expect(
        find.byKey(const Key('recoveryModalPasswordField')),
        findsOneWidget,
      );
    });
  });
}
