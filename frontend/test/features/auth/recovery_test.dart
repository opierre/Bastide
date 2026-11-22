import 'dart:io';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/router/app_router.dart';
import 'package:bastide/core/storage/token_store.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/application/auth_form_controllers.dart';
import 'package:bastide/features/auth/application/recovery_controllers.dart';
import 'package:bastide/features/auth/presentation/forgot_password_screen.dart';
import 'package:bastide/features/auth/presentation/recovery_code_modal.dart';
import 'package:bastide/features/auth/presentation/recovery_code_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockTokenStore extends Mock implements TokenStore {}

/// Records what « Enregistrer dans un fichier » writes, with no save dialog.
class _FakeRecoveryCodeFiles implements RecoveryCodeFiles {
  final saved = <(String, String)>[];
  bool cancel = false;
  bool fail = false;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    if (fail) throw const FileSystemException('read-only');
    if (cancel) return null;
    saved.add((suggestedName, contents));
    return '/tmp/$suggestedName';
  }
}

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
  late _FakeRecoveryCodeFiles files;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = _MockApiClient();
    tokenStore = _MockTokenStore();
    files = _FakeRecoveryCodeFiles();
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    when(() => tokenStore.write(any())).thenAnswer((_) async {});
    when(() => tokenStore.delete()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        tokenStoreProvider.overrideWithValue(tokenStore),
        recoveryCodeFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget wrap(
    Widget child, {
    Locale locale = const Locale('fr'),
    ThemeData? theme,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.dark,
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

      container.listen(registerControllerProvider, (_, _) {});
      await container.read(authControllerProvider.future);
      await container
          .read(registerControllerProvider.notifier)
          .submit(
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

      container.listen(loginControllerProvider, (_, _) {});
      await container.read(authControllerProvider.future);
      await container
          .read(loginControllerProvider.notifier)
          .submit(identifier: 'ada@example.com', password: 'secret');

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
      await tester.enterText(
        find.byKey(const Key('resetConfirmField')),
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

    testWidgets('a wrong code is said under the code field, not on the session', (
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

      // Said once, under the code field: no banner.
      expect(
        find.text(
          'Identifiant ou code de récupération incorrect. Vérifiez le code et réessayez.',
        ),
        findsOneWidget,
      );
      expect(container.read(authControllerProvider).hasError, isFalse);
      expect(container.read(pendingRecoveryCodeProvider), isNull);
    });

    testWidgets('the identifier field is labelled like the login one', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text("E-mail ou nom d’utilisateur"), findsOneWidget);
    });

    testWidgets('a short new password keeps the submit disabled', (
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

      expect(find.text('Email or username'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
      expect(find.text('Your data stays on this computer.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a confirmation that differs keeps the submit disabled', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const ForgotPasswordScreen()));
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
      await tester.enterText(
        find.byKey(const Key('resetConfirmField')),
        '${_strongPassword}x',
      );
      await tester.pump();

      expect(
        find.text('Les mots de passe ne correspondent pas.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('resetSubmitButton')));
      await tester.tap(find.byKey(const Key('resetSubmitButton')));
      await tester.pumpAndSettle();

      verifyNever(() => apiClient.post(any(), body: any(named: 'body')));
    });
  });

  group('recovery code screen', () {
    testWidgets('« J’ai noté ce code » releases the pending code', (
      tester,
    ) async {
      container.read(pendingRecoveryCodeProvider.notifier).show(_code);
      await tester.pumpWidget(wrap(const RecoveryCodeScreen()));
      await tester.pumpAndSettle();

      expect(find.text(_code), findsOneWidget);
      expect(
        find.text(
          'Notez ce code et gardez-le en lieu sûr : il ne sera plus affiché.',
        ),
        findsOneWidget,
      );
      expect(container.read(pendingRecoveryCodeProvider), _code);

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

      expect(find.text('I have written this code down'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (name, theme) in [
      ('dark', AppTheme.dark),
      ('light', AppTheme.light),
    ]) {
      testWidgets('keeps the code on one line above « Copier » ($name)', (
        tester,
      ) async {
        // The test font sets every glyph one em wide; measure the real face.
        final mono = FontLoader('Geist Mono')
          ..addFont(
            rootBundle.load(
              'assets/fonts/GeistMono/static/GeistMono-Regular.ttf',
            ),
          );
        await mono.load();

        container.read(pendingRecoveryCodeProvider.notifier).show(_code);
        await tester.pumpWidget(wrap(const RecoveryCodeScreen(), theme: theme));
        await tester.pumpAndSettle();

        final editable = tester
            .state<EditableTextState>(
              find.descendant(
                of: find.byKey(const Key('recoveryCodeText')),
                matching: find.byType(EditableText),
              ),
            )
            .renderEditable;
        // The whole code fits the well's width, so nothing wraps or scrolls.
        expect(
          editable.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(editable.size.width),
        );

        final well = tester.getRect(find.byKey(const Key('recoveryCodeWell')));
        final copy = tester.getRect(
          find.byKey(const Key('recoveryCodeCopyButton')),
        );
        expect(copy.top, greaterThanOrEqualTo(well.bottom));
        expect(copy.left, well.left);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('router', () {
    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: const Locale('fr'),
            theme: AppTheme.dark,
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
      await tester.enterText(
        find.byKey(const Key('resetConfirmField')),
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
    Future<void> open(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpWidget(
        wrap(
          // The modal as the recovery code row opens it.
          Builder(
            builder: (context) => TextButton(
              key: const Key('settingsRecoveryButton'),
              onPressed: () => showAppModal<void>(
                context: context,
                builder: (_) => const RegenerateRecoveryCodeModal(),
              ),
              child: const Text('open'),
            ),
          ),
          locale: locale ?? const Locale('fr'),
        ),
      );
      await tester.tap(find.byKey(const Key('settingsRecoveryButton')));
      await tester.pumpAndSettle();
    }

    Future<void> openAndSubmit(
      WidgetTester tester,
      String password, {
      Locale? locale,
    }) async {
      await open(tester, locale: locale);
      await tester.enterText(
        find.byKey(const Key('recoveryModalPasswordField')),
        password,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('recoveryModalGenerate')));
      await tester.pumpAndSettle();
    }

    void answerCode() => when(
      () => apiClient.post('/auth/recovery-code', body: any(named: 'body')),
    ).thenAnswer((_) async => {'recovery_code': _newCode});

    bool focusedWithin(Finder finder) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      return find
          .descendant(
            of: finder,
            matching: find.byElementPredicate((e) => e == focused),
          )
          .evaluate()
          .isNotEmpty;
    }

    double frameWidth(WidgetTester tester) =>
        tester.getSize(find.byKey(const Key('appModalFrame'))).width;

    testWidgets('asks the password in a 480 px form', (tester) async {
      await open(tester);

      expect(frameWidth(tester), 480);
      expect(find.text('Nouveau code de récupération'), findsOneWidget);
      expect(
        find.text(
          'Confirmez votre mot de passe pour générer un nouveau code. '
          'L’ancien cessera de fonctionner.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('recoveryModalCancel')), findsOneWidget);
      expect(find.text('Générer'), findsOneWidget);
      // The form's focus lands on its field.
      expect(
        focusedWithin(find.byKey(const Key('recoveryModalPasswordField'))),
        isTrue,
      );
    });

    testWidgets('the right password shows the new code once', (tester) async {
      answerCode();

      await openAndSubmit(tester, 'secret');

      verify(
        () =>
            apiClient.post('/auth/recovery-code', body: {'password': 'secret'}),
      ).called(1);
      expect(find.text(_newCode), findsOneWidget);
      expect(frameWidth(tester), 480);
      expect(
        find.text(
          'Notez ce code et gardez-le en lieu sûr : il ne sera plus affiché.',
        ),
        findsOneWidget,
      );
      expect(find.text('Copier'), findsOneWidget);
      expect(find.text('Enregistrer dans un fichier'), findsOneWidget);
      // One way out: no cancel, a single « Terminé ».
      expect(find.byKey(const Key('recoveryModalCancel')), findsNothing);

      await tester.tap(find.byKey(const Key('recoveryModalDone')));
      await tester.pumpAndSettle();
      expect(find.text(_newCode), findsNothing);
    });

    testWidgets('the shown code focuses « Copier » and ignores Escape', (
      tester,
    ) async {
      answerCode();
      await openAndSubmit(tester, 'secret');

      expect(
        focusedWithin(find.byKey(const Key('recoveryCodeCopyButton'))),
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(_newCode), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text(_newCode), findsOneWidget);

      // Enter on « Copier » copies; it never dismisses the code.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(_newCode), findsOneWidget);
    });

    testWidgets('« Enregistrer dans un fichier » writes the code', (
      tester,
    ) async {
      answerCode();
      await openAndSubmit(tester, 'secret');

      await tester.tap(find.byKey(const Key('recoveryCodeSaveButton')));
      await tester.pumpAndSettle();

      expect(files.saved, [
        ('code-de-recuperation-bastide.txt', '$_newCode\n'),
      ]);
      expect(find.text('Enregistré'), findsOneWidget);
      expect(find.text(_newCode), findsOneWidget);
    });

    testWidgets('a cancelled save dialog changes nothing', (tester) async {
      answerCode();
      files.cancel = true;
      await openAndSubmit(tester, 'secret');

      await tester.tap(find.byKey(const Key('recoveryCodeSaveButton')));
      await tester.pumpAndSettle();

      expect(find.text('Enregistrer dans un fichier'), findsOneWidget);
      expect(find.byKey(const Key('appModalSaveError')), findsNothing);
    });

    testWidgets('a file that cannot be written banners and keeps the code', (
      tester,
    ) async {
      answerCode();
      files.fail = true;
      await openAndSubmit(tester, 'secret');

      await tester.tap(find.byKey(const Key('recoveryCodeSaveButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('Le fichier n’a pas pu être enregistré. Réessayez.'),
        findsOneWidget,
      );
      expect(find.text(_newCode), findsOneWidget);
    });

    testWidgets('a wrong password is said under its field', (tester) async {
      when(
        () => apiClient.post('/auth/recovery-code', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'INVALID_CREDENTIALS', message: 'nope'),
      );

      await openAndSubmit(tester, 'wrong');

      expect(find.byKey(const Key('appModalSaveError')), findsNothing);
      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      expect(
        find.byKey(const Key('recoveryModalPasswordField')),
        findsOneWidget,
      );
    });

    testWidgets('any other failure is the frame banner', (tester) async {
      when(
        () => apiClient.post('/auth/recovery-code', body: any(named: 'body')),
      ).thenThrow(const ApiFailure(code: 'INTERNAL', message: 'boom'));

      await openAndSubmit(tester, 'secret');

      expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
      expect(
        find.byKey(const Key('recoveryModalPasswordField')),
        findsOneWidget,
      );
    });

    testWidgets('renders the shown code in English', (tester) async {
      answerCode();

      await openAndSubmit(tester, 'secret', locale: const Locale('en'));

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Save to a file'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
