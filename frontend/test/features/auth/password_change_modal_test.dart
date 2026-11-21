import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/presentation/password_change_modal.dart';
import 'package:bastide/features/settings/presentation/profile_section.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
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

const _current = 'ancien-mot-de-passe';
const _new = 'nouvelle-phrase-secrete';

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
      // The password row of Settings › Profil, which opens the modal.
      home: const Scaffold(
        body: SingleChildScrollView(child: ProfileSection()),
      ),
    ),
  );

  Future<void> open(WidgetTester tester, {Locale? locale}) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap(locale: locale ?? const Locale('fr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsPasswordButton')));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String current = _current,
    String newPassword = _new,
    String? confirm,
  }) async {
    await tester.enterText(
      find.byKey(const Key('passwordModalCurrentField')),
      current,
    );
    await tester.enterText(
      find.byKey(const Key('passwordModalNewField')),
      newPassword,
    );
    await tester.enterText(
      find.byKey(const Key('passwordModalConfirmField')),
      confirm ?? newPassword,
    );
    await tester.pump();
  }

  PrimaryButton saveButton(WidgetTester tester) =>
      tester.widget<PrimaryButton>(find.byKey(const Key('passwordModalSave')));

  testWidgets('the row has a generic description and no date', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsPasswordRow')), findsOneWidget);
    expect(
      find.text(
        "Au moins 12 caractères. Il protège l’accès à vos données sur cet "
        'ordinateur.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Modifié le'), findsNothing);
    expect(find.textContaining('Dernier code'), findsNothing);
  });

  testWidgets('opens on the current, new and confirmation fields', (
    tester,
  ) async {
    await open(tester);

    expect(find.byType(PasswordChangeModal), findsOneWidget);
    expect(find.text('Mot de passe actuel'), findsOneWidget);
    expect(find.text('Nouveau mot de passe'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    expect(find.text('Votre code de récupération reste valable.'), findsOne);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a short new password keeps the save disabled', (tester) async {
    await open(tester);

    await fill(tester, newPassword: 'a' * 11);

    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a confirmation that differs keeps the save disabled', (
    tester,
  ) async {
    await open(tester);

    await fill(tester, confirm: '$_new-x');

    expect(find.text('Les mots de passe ne correspondent pas.'), findsOne);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('saving sends both passwords, closes and toasts', (tester) async {
    when(
      () => apiClient.put('/auth/me/password', body: any(named: 'body')),
    ).thenAnswer((_) async => null);
    await open(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('passwordModalSave')));
    await tester.pumpAndSettle();

    verify(
      () => apiClient.put(
        '/auth/me/password',
        body: {'current_password': _current, 'new_password': _new},
      ),
    ).called(1);
    expect(find.byType(PasswordChangeModal), findsNothing);
    expect(find.text('Mot de passe modifié.'), findsOneWidget);
    // Let the toast leave so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a wrong current password is said under its field', (
    tester,
  ) async {
    when(
      () => apiClient.put('/auth/me/password', body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'INVALID_CREDENTIALS', message: 'nope'));
    await open(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('passwordModalSave')));
    await tester.pumpAndSettle();

    expect(find.byType(PasswordChangeModal), findsOneWidget);
    expect(find.text('Mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('renders in English', (tester) async {
    await open(tester, locale: const Locale('en'));

    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('Your recovery code stays valid.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
