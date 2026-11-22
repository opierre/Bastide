import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/presentation/email_change_modal.dart';
import 'package:bastide/features/settings/presentation/profile_section.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/desktop_surface.dart';
import '../../support/fake_auth_controller.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'ada',
  locale: 'fr',
  currency: 'EUR',
);

const _newEmail = 'ada.lovelace@example.org';
const _password = 'correct-horse-battery-staple';

Map<String, dynamic> _userJson(String email) => {
  'id': 'u1',
  'email': email,
  'display_name': 'ada',
  'locale': 'fr',
  'currency': 'EUR',
  'created_at': '2026-10-09T00:00:00Z',
};

void main() {
  late _MockApiClient apiClient;

  setUp(() => apiClient = _MockApiClient());

  Widget wrap({Locale locale = const Locale('fr')}) => ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(initialUser: _user),
      ),
      apiClientProvider.overrideWithValue(apiClient),
    ],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The email row of Settings › Profil, which opens the modal.
      home: const Scaffold(
        body: SingleChildScrollView(child: ProfileSection()),
      ),
    ),
  );

  Future<void> open(WidgetTester tester, {Locale? locale}) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap(locale: locale ?? const Locale('fr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsEmailButton')));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = _newEmail,
    String password = _password,
  }) async {
    await tester.enterText(find.byKey(const Key('emailModalField')), email);
    await tester.enterText(
      find.byKey(const Key('emailModalPasswordField')),
      password,
    );
    await tester.pump();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<PrimaryButton>(find.byKey(const Key('emailModalSave')))
          .onPressed !=
      null;

  void answerPut(Object Function() answer) => when(
    () => apiClient.put('/auth/me/email', body: any(named: 'body')),
  ).thenAnswer((_) async => answer());

  void failPut(String code) => when(
    () => apiClient.put('/auth/me/email', body: any(named: 'body')),
  ).thenThrow(ApiFailure(code: code, message: code));

  testWidgets('the email row shows the address and a « Modifier » button', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('settingsEmail'))).data,
      'ada@example.com',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('settingsEmailRow')),
        matching: find.text('Modifier'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens as the 420 px form with the current address', (
    tester,
  ) async {
    await open(tester);

    expect(tester.getSize(find.byKey(const Key('appModalFrame'))).width, 420);
    expect(find.text('Changer d’adresse e-mail'), findsOneWidget);
    expect(
      find.text('La nouvelle adresse remplace l’ancienne pour vous connecter.'),
      findsOneWidget,
    );
    expect(find.text('Nouvelle adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe actuel'), findsOneWidget);
    expect(find.byKey(const Key('emailModalCancel')), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('saving trims the address, updates the session and closes', (
    tester,
  ) async {
    answerPut(() => {'user': _userJson(_newEmail)});
    await open(tester);

    await fill(tester, email: '  $_newEmail ');
    await tester.tap(find.byKey(const Key('emailModalSave')));
    await tester.pumpAndSettle();

    verify(
      () => apiClient.put(
        '/auth/me/email',
        body: {'email': _newEmail, 'current_password': _password},
      ),
    ).called(1);
    expect(find.byType(EmailChangeModal), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('settingsEmail'))).data,
      _newEmail,
    );
  });

  testWidgets('a malformed address is refused under the field, unsent', (
    tester,
  ) async {
    await open(tester);

    await fill(tester, email: 'ada@example');

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    verifyNever(() => apiClient.put(any(), body: any(named: 'body')));
  });

  testWidgets('an unchanged address or no password cannot be saved', (
    tester,
  ) async {
    await open(tester);

    await fill(tester, email: ' ada@example.com ');
    expect(saveEnabled(tester), isFalse);

    await fill(tester, password: '');
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('a taken address keeps the modal open with the reason', (
    tester,
  ) async {
    failPut('EMAIL_TAKEN');
    await open(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('emailModalSave')));
    await tester.pumpAndSettle();

    expect(find.byType(EmailChangeModal), findsOneWidget);
    expect(
      find.text('Cette adresse e-mail est déjà utilisée.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('appModalSaveError')), findsNothing);
  });

  testWidgets('an address the backend refuses is said under the field', (
    tester,
  ) async {
    failPut('EMAIL_INVALID');
    await open(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('emailModalSave')));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(find.byKey(const Key('appModalSaveError')), findsNothing);
  });

  testWidgets('a wrong password is said under its field', (tester) async {
    failPut('INVALID_CREDENTIALS');
    await open(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('emailModalSave')));
    await tester.pumpAndSettle();

    expect(find.byType(EmailChangeModal), findsOneWidget);
    expect(find.text('Mot de passe incorrect.'), findsOneWidget);
    expect(find.byKey(const Key('appModalSaveError')), findsNothing);
  });

  testWidgets('any other failure is the frame banner, input kept', (
    tester,
  ) async {
    failPut('INTERNAL');
    await open(tester);

    await fill(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
    expect(find.text(_newEmail), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('Escape on an edited address asks before dropping it', (
    tester,
  ) async {
    await open(tester);

    await fill(tester, password: '');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalDiscard')), findsOneWidget);
  });

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    await open(tester, locale: const Locale('en'));

    expect(find.text('Change email address'), findsOneWidget);
    expect(find.text('New email address'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
