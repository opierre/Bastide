import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
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

/// The French format error, with its no-break spaces.
const _formatError =
    '3 à 32 caractères : lettres sans accent, chiffres, espaces, '
    '« . », « _ » ou « - ».';

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
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The username row of Settings › Profil, which opens the modal.
      home: const Scaffold(
        body: SingleChildScrollView(child: ProfileSection()),
      ),
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

  testWidgets('the row says the name signs in, alongside the email', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.text('Vous pouvez vous connecter avec ce nom ou avec votre e-mail.'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('settingsDisplayName'))).data,
      'ada',
    );
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('saving a new name updates the session and closes the modal', (
    tester,
  ) async {
    useDesktopSurface(tester);
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
      tester.widget<Text>(find.byKey(const Key('settingsDisplayName'))).data,
      'ada.lovelace',
    );
  });

  testWidgets('a taken name keeps the modal open with the reason', (
    tester,
  ) async {
    useDesktopSurface(tester);
    when(
      () => apiClient.patch('/auth/me', body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'DISPLAY_NAME_TAKEN', message: 'taken'));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'bruno');
    await tester.tap(find.byKey(const Key('displayNameModalSave')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('displayNameModalField')), findsOneWidget);
    expect(find.text("Ce nom d’utilisateur est déjà pris."), findsOneWidget);
  });

  testWidgets('opens as the 420 px v2 form, focus on the field', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsDisplayNameButton')));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('appModalFrame'))).width, 420);
    expect(find.text('Changer de nom d’utilisateur'), findsOneWidget);
    expect(
      find.text('Le nouveau nom remplace l’ancien pour vous connecter.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('displayNameModalCancel')), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byKey(const Key('displayNameModalField')),
        matching: find.byWidget(focused.widget),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Escape on an edited name asks before dropping it', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'ada.l');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalDiscard')), findsOneWidget);
    await tester.tap(find.byKey(const Key('appModalDiscardConfirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('displayNameModal')), findsNothing);
  });

  testWidgets('a failure other than a taken name is the frame banner', (
    tester,
  ) async {
    useDesktopSurface(tester);
    when(
      () => apiClient.patch('/auth/me', body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'INTERNAL', message: 'boom'));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'bruno');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
    expect(find.text('bruno'), findsOneWidget);
  });

  testWidgets('a name with spaces is saved with its inner spaces collapsed', (
    tester,
  ) async {
    useDesktopSurface(tester);
    when(
      () => apiClient.patch('/auth/me', body: any(named: 'body')),
    ).thenAnswer((_) async => {'user': _userJson('Ada Lovelace')});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, ' Ada   Lovelace ');
    expect(find.text(_formatError), findsNothing);
    await tester.tap(find.byKey(const Key('displayNameModalSave')));
    await tester.pumpAndSettle();

    verify(
      () => apiClient.patch('/auth/me', body: {'display_name': 'Ada Lovelace'}),
    ).called(1);
    expect(
      tester.widget<Text>(find.byKey(const Key('settingsDisplayName'))).data,
      'Ada Lovelace',
    );
  });

  testWidgets('a change of case alone can be saved', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'Ada');

    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('a malformed or unchanged name cannot be saved', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await openAndType(tester, 'ada@home');
    expect(saveEnabled(tester), isFalse);
    expect(find.text(_formatError), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('displayNameModalField')),
      '  ada ',
    );
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    verifyNever(() => apiClient.patch(any(), body: any(named: 'body')));
  });

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Log out'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
