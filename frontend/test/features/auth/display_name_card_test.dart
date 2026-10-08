import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/primary_button.dart';
import 'package:finstride/features/auth/application/auth_controller.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
import 'package:finstride/features/auth/presentation/display_name_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_auth_controller.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'ada',
  locale: 'fr',
  currency: 'EUR',
);

Map<String, dynamic> _userJson(String displayName) => {
  'id': 'u1',
  'email': 'ada@example.com',
  'display_name': displayName,
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
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DisplayNameCard()),
    ),
  );

  Future<void> openAndType(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('settingsDisplayNameButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('displayNameModalField')),
      name,
    );
    await tester.pump();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<PrimaryButton>(find.byKey(const Key('displayNameModalSave')))
          .onPressed !=
      null;

  testWidgets('the card says the name signs in, alongside the email', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.text('Vous pouvez vous connecter avec ada ou avec votre e-mail.'),
      findsOneWidget,
    );
  });

  testWidgets('saving a new name updates the session and closes the modal', (
    tester,
  ) async {
    when(
      () => apiClient.patch('/auth/me', body: any(named: 'body')),
    ).thenAnswer((_) async => {'user': _userJson('ada.lovelace')});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'Ada.Lovelace');
    await tester.tap(find.byKey(const Key('displayNameModalSave')));
    await tester.pumpAndSettle();

    verify(
      () => apiClient.patch('/auth/me', body: {'display_name': 'Ada.Lovelace'}),
    ).called(1);
    expect(find.byKey(const Key('displayNameModalField')), findsNothing);
    expect(
      find.text(
        'Vous pouvez vous connecter avec ada.lovelace ou avec votre e-mail.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a taken name keeps the modal open with the reason', (
    tester,
  ) async {
    when(
      () => apiClient.patch('/auth/me', body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'DISPLAY_NAME_TAKEN', message: 'taken'));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'bruno');
    await tester.tap(find.byKey(const Key('displayNameModalSave')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('displayNameModalField')), findsOneWidget);
    expect(find.text("Ce nom d'utilisateur est déjà pris."), findsOneWidget);
  });

  testWidgets('a malformed or unchanged name cannot be saved', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'a b');
    expect(saveEnabled(tester), isFalse);
    expect(
      find.text(
        '3 à 32 caractères : lettres sans accent, chiffres, « . », « _ » ou « - ».',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('displayNameModalField')),
      'ADA',
    );
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    verifyNever(() => apiClient.patch(any(), body: any(named: 'body')));
  });

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Change…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
