import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/l10n/locale_provider.dart';
import 'package:bastide/core/storage/token_store.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/application/auth_form_controllers.dart';
import 'package:bastide/features/auth/presentation/login_screen.dart';
import 'package:bastide/features/auth/presentation/register_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_auth_forms.dart';

/// The app's own wiring: the locale comes from [localeProvider], so the
/// language segment switches the screen like it does in the app.
/// The availability checks answer at once from [availability] unless
/// [apiClient] is given: then the real, debounced controller asks it.
Widget _wrap({
  required FakeRegisterController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  FakeRegisterAvailabilityController? availability,
  ApiClient? apiClient,
}) {
  return ProviderScope(
    overrides: [
      registerControllerProvider.overrideWith(() => controller),
      if (apiClient != null)
        apiClientProvider.overrideWithValue(apiClient)
      else
        registerAvailabilityProvider.overrideWith(
          () => availability ?? FakeRegisterAvailabilityController(),
        ),
      localeProvider.overrideWith(() => _FixedLocale(locale)),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        locale: ref.watch(localeProvider),
        theme: theme ?? AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegisterScreen(),
      ),
    ),
  );
}

class _MockApiClient extends Mock implements ApiClient {}

class _MockTokenStore extends Mock implements TokenStore {}

class _FixedLocale extends LocaleController {
  _FixedLocale(this.initial);

  final Locale initial;

  @override
  Locale build() => initial;
}

/// The reference frame of `00-design-system.md`.
void _useReferenceFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _validPassword = 'correct-horse-7';

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('registerDisplayNameField')),
    'ada.lovelace',
  );
  await tester.enterText(
    find.byKey(const Key('registerEmailField')),
    'ada@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('registerPasswordField')),
    _validPassword,
  );
  // Lets a real availability check's debounce run out.
  await tester.pump(registerAvailabilityDebounce);
  await tester.pumpAndSettle();
}

const _emailTaken = 'Cet e-mail a déjà un compte. Connectez-vous.';
const _nameTaken = "Ce nom d’utilisateur est déjà pris.";

/// Answers `/auth/availability` from [takenEmails] and [takenNames], or
/// fails with [failure].
_MockApiClient _availabilityApi({
  Set<String> takenEmails = const {},
  Set<String> takenNames = const {},
  Object? failure,
}) {
  final apiClient = _MockApiClient();
  when(
    () => apiClient.post('/auth/availability', body: any(named: 'body')),
  ).thenAnswer((invocation) async {
    if (failure != null) throw failure;
    final body = invocation.namedArguments[#body] as Map<String, dynamic>;
    final email = body['email'] as String?;
    final name = body['display_name'] as String?;
    return {
      'email_available': email == null ? null : !takenEmails.contains(email),
      'display_name_available': name == null
          ? null
          : !takenNames.contains(name),
    };
  });
  return apiClient;
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('registerSubmitButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('registerSubmitButton')));
  await tester.pumpAndSettle();
}

bool _submitEnabled(WidgetTester tester) =>
    tester
        .widget<PrimaryButton>(find.byKey(const Key('registerSubmitButton')))
        .onPressed !=
    null;

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  group('#320: availability checked while typing', () {
    testWidgets('asks once the user pauses, for the latest value only', (
      tester,
    ) async {
      final apiClient = _availabilityApi();
      await tester.pumpWidget(
        _wrap(controller: FakeRegisterController(), apiClient: apiClient),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('registerEmailField')),
        'ada@example.com',
      );
      await tester.pump(registerAvailabilityDebounce ~/ 2);
      await tester.enterText(
        find.byKey(const Key('registerEmailField')),
        'ada@example.org',
      );
      await tester.pump(
        registerAvailabilityDebounce - const Duration(milliseconds: 1),
      );
      verifyNever(
        () => apiClient.post('/auth/availability', body: any(named: 'body')),
      );

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      verify(
        () => apiClient.post(
          '/auth/availability',
          body: {'email': 'ada@example.org'},
        ),
      ).called(1);
    });

    testWidgets('a malformed value is never sent', (tester) async {
      final apiClient = _availabilityApi();
      await tester.pumpWidget(
        _wrap(controller: FakeRegisterController(), apiClient: apiClient),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('registerEmailField')),
        'ada@',
      );
      await tester.enterText(
        find.byKey(const Key('registerDisplayNameField')),
        'a@',
      );
      await tester.pump(registerAvailabilityDebounce);
      await tester.pumpAndSettle();

      verifyNever(
        () => apiClient.post('/auth/availability', body: any(named: 'body')),
      );
    });

    testWidgets(
      'a taken name and a taken e-mail show together, before any submit',
      (tester) async {
        final controller = FakeRegisterController();
        await tester.pumpWidget(
          _wrap(
            controller: controller,
            apiClient: _availabilityApi(
              takenEmails: {'ada@example.com'},
              takenNames: {'ada.lovelace'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _fillValidForm(tester);

        expect(find.text(_emailTaken), findsOneWidget);
        expect(find.text(_nameTaken), findsOneWidget);
        expect(_submitEnabled(tester), isFalse);
        expect(controller.calls, isEmpty);
      },
    );

    testWidgets('submit waits for the check, then one tap registers', (
      tester,
    ) async {
      final controller = FakeRegisterController();
      await tester.pumpWidget(
        _wrap(controller: controller, apiClient: _availabilityApi()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('registerDisplayNameField')),
        'ada.lovelace',
      );
      await tester.enterText(
        find.byKey(const Key('registerEmailField')),
        'ada@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('registerPasswordField')),
        _validPassword,
      );
      await tester.pump();
      // Still checking: not yet valid.
      expect(_submitEnabled(tester), isFalse);

      await tester.pump(registerAvailabilityDebounce);
      await tester.pumpAndSettle();
      expect(_submitEnabled(tester), isTrue);

      await _tapSubmit(tester);
      expect(controller.calls, hasLength(1));
    });

    testWidgets('fixing a taken e-mail clears its error while typing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeRegisterController(),
          availability: FakeRegisterAvailabilityController(
            takenEmails: {'ada@example.com'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      expect(find.text(_emailTaken), findsOneWidget);
      expect(_submitEnabled(tester), isFalse);

      await tester.enterText(
        find.byKey(const Key('registerEmailField')),
        'ada.byron@example.com',
      );
      await tester.pumpAndSettle();

      expect(find.text(_emailTaken), findsNothing);
      expect(_submitEnabled(tester), isTrue);
    });

    testWidgets('a failed check does not hold the form', (tester) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeRegisterController(),
          apiClient: _availabilityApi(
            failure: const ApiFailure(code: 'NETWORK_ERROR', message: 'down'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);

      expect(find.text(_emailTaken), findsNothing);
      expect(_submitEnabled(tester), isTrue);
    });
  });

  testWidgets('the v2 column: no strength meter, the currency microcopy', (
    tester,
  ) async {
    _useReferenceFrame(tester);
    await tester.pumpWidget(_wrap(controller: FakeRegisterController()));
    await tester.pumpAndSettle();

    expect(find.text("Nom d’utilisateur"), findsOneWidget);
    expect(find.text('Nom affiché'), findsNothing);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Devise'), findsOneWidget);
    expect(
      find.text(
        'La langue se change dans les paramètres. La devise est définitive et s’applique à tous vos comptes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Déjà un compte ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(
      find.text('Vos données restent sur cet ordinateur.'),
      findsOneWidget,
    );
    expect(find.text('Robuste'), findsNothing);
    expect(find.text('Trop faible'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('registerSubmitButton'))).width,
      AppSizes.authColumn,
    );
    expect(
      tester.getSize(find.byKey(const Key('registerCurrencyField'))).height,
      AppSizes.toolbarSelect,
    );
  });

  testWidgets('the currency reads « EUR, euro »', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeRegisterController()));
    await tester.pumpAndSettle();

    expect(find.text('EUR, euro'), findsOneWidget);
  });

  testWidgets('empty: submit disabled, the password minimum as guidance', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeRegisterController()));
    await tester.pumpAndSettle();

    expect(_submitEnabled(tester), isFalse);
    expect(find.text('12 caractères minimum.'), findsOneWidget);
  });

  testWidgets('valid: the check form of the helper and submit enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeRegisterController()));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);

    expect(find.byKey(const Key('newPasswordHelperValid')), findsOneWidget);
    expect(find.text('15 caractères. Le minimum est de 12.'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('a short password left behind turns into « Encore n »', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeRegisterController()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registerPasswordField')));
    await tester.enterText(
      find.byKey(const Key('registerPasswordField')),
      'short-pw',
    );
    await tester.pumpAndSettle();
    // Still typing: guidance, not an error.
    expect(find.text('12 caractères minimum.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('registerEmailField')));
    await tester.pumpAndSettle();

    expect(find.text('Encore 4 caractères.'), findsOneWidget);
    final border =
        tester
                .widget<TextField>(
                  find.byKey(const Key('registerPasswordField')),
                )
                .decoration
                ?.enabledBorder
            as OutlineInputBorder?;
    expect(border?.borderSide.color, AppColors.dark.negative);
    expect(_submitEnabled(tester), isFalse);
  });

  testWidgets('a taken email is reported on the field, not as a banner', (
    tester,
  ) async {
    final controller = FakeRegisterController(
      error: const ApiFailure(code: 'EMAIL_TAKEN', message: 'taken'),
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await _tapSubmit(tester);

    expect(
      find.text('Cet e-mail a déjà un compte. Connectez-vous.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('registerErrorText')), findsNothing);
  });

  testWidgets('a malformed name is flagged and keeps submit disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeRegisterController()));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    expect(_submitEnabled(tester), isTrue);

    await tester.enterText(
      find.byKey(const Key('registerDisplayNameField')),
      'Ada@Lovelace',
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '3 à 32 caractères : lettres sans accent, chiffres, espaces, '
        '« . », « _ » ou « - ».',
      ),
      findsOneWidget,
    );
    expect(_submitEnabled(tester), isFalse);
  });

  testWidgets('a name with a space is accepted and sent as typed', (
    tester,
  ) async {
    final controller = FakeRegisterController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('registerDisplayNameField')),
      'Camille Dubois',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('lettres sans accent'), findsNothing);
    expect(_submitEnabled(tester), isTrue);
    await _tapSubmit(tester);
    expect(controller.calls.single.displayName, 'Camille Dubois');
  });

  testWidgets('a taken name is reported on its field', (tester) async {
    final controller = FakeRegisterController(
      error: const ApiFailure(code: 'DISPLAY_NAME_TAKEN', message: 'taken'),
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await _tapSubmit(tester);

    expect(find.text("Ce nom d’utilisateur est déjà pris."), findsOneWidget);
  });

  testWidgets('loading: « Création… » and the fields disabled', (tester) async {
    final hold = Completer<void>();
    await tester.pumpWidget(
      _wrap(controller: FakeRegisterController(hold: hold)),
    );
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pump();

    expect(find.text('Création…'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('registerEmailField')))
          .enabled,
      isFalse,
    );

    hold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('choosing English switches the screen at once', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeRegisterController()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('registerLocaleEnglishOption')),
    );
    await tester.tap(find.byKey(const Key('registerLocaleEnglishOption')));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Display name'), findsNothing);
    expect(find.text('EUR, euro'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets(
    'submitting calls the controller with the chosen locale and currency',
    (tester) async {
      final controller = FakeRegisterController();
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);

      await tester.ensureVisible(
        find.byKey(const Key('registerLocaleEnglishOption')),
      );
      await tester.tap(find.byKey(const Key('registerLocaleEnglishOption')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('registerCurrencyField')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registerCurrencyField')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.ancestor(
          of: find.text('USD, US dollar'),
          matching: find.byType(MenuItemButton),
        ),
      );
      await tester.pumpAndSettle();

      await _tapSubmit(tester);

      expect(controller.calls, hasLength(1));
      final call = controller.calls.single;
      expect(call.email, 'ada@example.com');
      expect(call.password, _validPassword);
      expect(call.displayName, 'ada.lovelace');
      expect(call.locale, 'en');
      expect(call.currency, 'USD');
    },
  );

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    testWidgets('renders in the $name theme at the reference frame', (
      tester,
    ) async {
      _useReferenceFrame(tester);
      await tester.pumpWidget(
        _wrap(controller: FakeRegisterController(), theme: theme),
      );
      await tester.pumpAndSettle();

      final colors = theme.extension<AppColors>()!;
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        colors.bg,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders under en with the English segment selected', (
    tester,
  ) async {
    _useReferenceFrame(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeRegisterController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('12 characters minimum.'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('registerSubmitButton'))).width,
      AppSizes.authColumn,
    );
    expect(tester.takeException(), isNull);
  });

  group('#319: only registration errors, cleared on edit', () {
    const loginError = 'Identifiant ou mot de passe incorrect.';

    testWidgets('a failed login does not follow the user to « Inscription »', (
      tester,
    ) async {
      _useReferenceFrame(tester);
      final apiClient = _MockApiClient();
      final tokenStore = _MockTokenStore();
      when(() => tokenStore.read()).thenAnswer((_) async => null);
      when(() => tokenStore.write(any())).thenAnswer((_) async {});
      when(
        () => apiClient.post('/auth/login', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'INVALID_CREDENTIALS', message: 'invalid'),
      );
      when(
        () => apiClient.post('/auth/availability', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => {'email_available': true, 'display_name_available': true},
      );
      when(
        () => apiClient.post('/auth/register', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => {
          'token': 'tok-1',
          'user': {
            'id': 'u1',
            'email': 'ada@example.com',
            'display_name': 'ada.lovelace',
            'locale': 'fr',
            'currency': 'EUR',
          },
          'recovery_code': 'ABCD-EFGH-IJKL-MNOP',
        },
      );
      final router = GoRouter(
        initialLocation: LoginScreen.path,
        routes: [
          GoRoute(
            path: LoginScreen.path,
            builder: (_, _) => const LoginScreen(),
          ),
          GoRoute(
            path: RegisterScreen.path,
            builder: (_, _) => const RegisterScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          tokenStoreProvider.overrideWithValue(tokenStore),
          localeProvider.overrideWith(() => _FixedLocale(const Locale('fr'))),
        ],
      );
      addTearDown(container.dispose);

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

      await tester.enterText(
        find.byKey(const Key('loginIdentifierField')),
        'ada@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('loginPasswordField')),
        'wrong-password',
      );
      await tester.tap(find.byKey(const Key('loginSubmitButton')));
      await tester.pumpAndSettle();
      expect(find.text(loginError), findsOneWidget);

      await tester.tap(find.byKey(const Key('goToRegisterButton')));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text(loginError), findsNothing);

      await _fillValidForm(tester);
      await _tapSubmit(tester);

      expect(find.text(loginError), findsNothing);
      expect(find.byKey(const Key('registerErrorText')), findsNothing);
      expect(container.read(authControllerProvider).value, isNotNull);
    });

    testWidgets('an error under the button goes once a field is edited', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeRegisterController(
            error: const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await _tapSubmit(tester);
      expect(find.byKey(const Key('registerErrorText')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('registerPasswordField')),
        '${_validPassword}x',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('registerErrorText')), findsNothing);
    });

    testWidgets('a taken e-mail goes once the e-mail is edited', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeRegisterController(
            error: const ApiFailure(code: 'EMAIL_TAKEN', message: 'taken'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const taken = 'Cet e-mail a déjà un compte. Connectez-vous.';

      await _fillValidForm(tester);
      await _tapSubmit(tester);
      expect(find.text(taken), findsOneWidget);

      // Another field's edit doesn't answer it.
      await tester.enterText(
        find.byKey(const Key('registerDisplayNameField')),
        'ada.byron',
      );
      await tester.pumpAndSettle();
      expect(find.text(taken), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('registerEmailField')),
        'ada.byron@example.com',
      );
      await tester.pumpAndSettle();
      expect(find.text(taken), findsNothing);
    });
  });
}
