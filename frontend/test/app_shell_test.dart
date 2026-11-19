import 'package:bastide/app.dart';
import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/core/l10n/locale_provider.dart';
import 'package:bastide/core/storage/ui_preferences.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/domain/avatar_choice.dart';
import 'package:bastide/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:mocktail/mocktail.dart';

import 'support/fake_accounts_controller.dart';
import 'support/fake_auth_controller.dart';
import 'support/fake_backend.dart';
import 'support/fake_ui_preferences.dart';

const _signedInUser = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

final _authenticatedOverrides = [
  backendControllerProvider.overrideWith(ReadyBackendController.new),
  authControllerProvider.overrideWith(
    () => FakeAuthController(initialUser: _signedInUser),
  ),
  accountsControllerProvider.overrideWith(() => FakeAccountsController()),
];

/// The frame is specified at 1440×900 (docs/design/00 §Layout invariant), and
/// the top bar's contextual controls are sized for it. Testing the chrome at
/// flutter_test's default 800×600 would assert against a window size the design
/// does not target.
void _useDesignViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The sidebar's user row carries the avatar, the display name and the
/// chevron only: the email adds nothing in a local, single-user app. The name
/// sits on the row's vertical centre.
void _expectUserPillShowsNameOnly(WidgetTester tester) {
  final pill = find.byKey(const Key('userMenuButton'));
  final name = find.descendant(
    of: pill,
    matching: find.text(_signedInUser.displayName),
  );
  expect(name, findsOneWidget);
  expect(
    find.descendant(of: pill, matching: find.text(_signedInUser.email)),
    findsNothing,
  );
  expect(
    find.descendant(
      of: pill,
      matching: find.byIcon(LucideIcons300.chevronsUpDown),
    ),
    findsOneWidget,
  );
  expect(
    tester.getCenter(name).dy,
    moreOrLessEquals(tester.getCenter(pill).dy, epsilon: 1),
  );
}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  testWidgets('the pill shows an uploaded picture, fetched once', (
    tester,
  ) async {
    _useDesignViewport(tester);
    final api = _MockApiClient();
    when(() => api.getBytes('/auth/me/avatar')).thenAnswer(
      (_) async => ApiBytesResponse(
        // A 1×1 transparent PNG.
        bytes: Uint8List.fromList(const [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, //
          0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
          0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
          0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
          0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
          0x82,
        ]),
        headers: const {'etag': '"1"'},
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiPreferencesStoreProvider.overrideWithValue(
            FakeUiPreferencesStore(),
          ),
          backendControllerProvider.overrideWith(ReadyBackendController.new),
          authControllerProvider.overrideWith(
            () => FakeAuthController(
              initialUser: const AuthUser(
                id: 'u1',
                email: 'ada@example.com',
                displayName: 'Ada',
                locale: 'fr',
                currency: 'EUR',
                avatar: PictureChoice(),
              ),
            ),
          ),
          accountsControllerProvider.overrideWith(
            () => FakeAccountsController(),
          ),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('userMenuButton')),
        matching: find.byKey(const Key('userAvatarPicture')),
      ),
      findsOneWidget,
    );
    verify(() => api.getBytes('/auth/me/avatar')).called(1);
  });

  testWidgets('shell renders the fixed sidebar and top bar', (tester) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._authenticatedOverrides,
          uiPreferencesStoreProvider.overrideWithValue(
            FakeUiPreferencesStore(),
          ),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appNavRail')), findsOneWidget);
    expect(find.byKey(const Key('appTopBar')), findsOneWidget);
    expect(find.byKey(const Key('screen-dashboard')), findsOneWidget);
  });

  testWidgets(
    'the privacy badge sits at the sidebar foot, not in a bottom bar',
    (tester) async {
      _useDesignViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _authenticatedOverrides,
          child: const BastideApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appBottomBar')), findsNothing);
      expect(find.byKey(const Key('sidebarPrivacyBadge')), findsOneWidget);
    },
  );

  testWidgets('Ctrl+B collapses the sidebar and the choice is saved', (
    tester,
  ) async {
    _useDesignViewport(tester);
    final store = FakeUiPreferencesStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._authenticatedOverrides,
          uiPreferencesStoreProvider.overrideWithValue(store),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    double railWidth() =>
        tester.getSize(find.byKey(const Key('appNavRail'))).width;
    expect(railWidth(), AppSizes.sidebar);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(railWidth(), AppSizes.sidebarCollapsed);
    // The label is gone but the destination itself is not — the collapsed rail
    // is icon-only, never a shorter menu.
    expect(find.text('Comptes'), findsNothing);
    expect(find.byIcon(LucideIcons300.wallet), findsOneWidget);
    expect(find.byIcon(LucideIcons300.lock), findsOneWidget);
    expect(store.writes, [true]);
  });

  testWidgets('a collapsed sidebar saved on this device comes back', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._authenticatedOverrides,
          uiPreferencesStoreProvider.overrideWithValue(
            FakeUiPreferencesStore(sidebarCollapsed: true),
          ),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('appNavRail'))).width,
      AppSizes.sidebarCollapsed,
    );
  });

  testWidgets('Paramètres › Barre latérale switches the sidebar', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._authenticatedOverrides,
          uiPreferencesStoreProvider.overrideWithValue(
            FakeUiPreferencesStore(),
          ),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsSidebarCollapsedOption')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('appNavRail'))).width,
      AppSizes.sidebarCollapsed,
    );

    await tester.tap(find.byKey(const Key('settingsSidebarExpandedOption')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('appNavRail'))).width,
      AppSizes.sidebar,
    );
  });

  testWidgets('tapping a nav item swaps the content region, not the chrome', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._authenticatedOverrides,
          uiPreferencesStoreProvider.overrideWithValue(
            FakeUiPreferencesStore(),
          ),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comptes'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen-accounts')), findsOneWidget);
    expect(find.byKey(const Key('screen-dashboard')), findsNothing);
    expect(find.byKey(const Key('appNavRail')), findsOneWidget);
    expect(find.byKey(const Key('appTopBar')), findsOneWidget);
  });

  testWidgets('renders under fr without missing localized keys', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._authenticatedOverrides,
          uiPreferencesStoreProvider.overrideWithValue(
            FakeUiPreferencesStore(),
          ),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Comptes'), findsOneWidget);
    _expectUserPillShowsNameOnly(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._authenticatedOverrides,
          uiPreferencesStoreProvider.overrideWithValue(
            FakeUiPreferencesStore(),
          ),
          localeProvider.overrideWith(() => _EnLocaleController()),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Accounts'), findsOneWidget);
    _expectUserPillShowsNameOnly(tester);
    expect(tester.takeException(), isNull);
  });

  group('user menu', () {
    late FakeAuthController auth;

    Future<void> pumpApp(WidgetTester tester) async {
      _useDesignViewport(tester);
      auth = FakeAuthController(initialUser: _signedInUser);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiPreferencesStoreProvider.overrideWithValue(
              FakeUiPreferencesStore(),
            ),
            backendControllerProvider.overrideWith(ReadyBackendController.new),
            authControllerProvider.overrideWith(() => auth),
            accountsControllerProvider.overrideWith(
              () => FakeAccountsController(),
            ),
          ],
          child: const BastideApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String itemKey) async {
      await tester.tap(find.byKey(const Key('userMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(itemKey)));
      await tester.pumpAndSettle();
    }

    testWidgets('the pill follows a new avatar choice at once', (tester) async {
      await pumpApp(tester);
      final pillPreset = find.descendant(
        of: find.byKey(const Key('userMenuButton')),
        matching: find.byKey(const Key('userAvatarPreset')),
      );
      expect(pillPreset, findsNothing);

      auth.replaceUser(
        const AuthUser(
          id: 'u1',
          email: 'ada@example.com',
          displayName: 'Ada',
          locale: 'fr',
          currency: 'EUR',
          avatar: PresetChoice(AvatarPreset.teal),
        ),
      );
      await tester.pumpAndSettle();

      expect(pillPreset, findsOneWidget);
    });

    testWidgets('log out ends the session and returns to the login screen', (
      tester,
    ) async {
      await pumpApp(tester);

      await choose(tester, 'userMenuLogoutItem');

      expect(auth.logoutCallCount, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('appTopBar')), findsNothing);
    });

    testWidgets('Paramètres opens the settings panel', (tester) async {
      await pumpApp(tester);

      await choose(tester, 'userMenuSettingsItem');

      expect(find.byKey(const Key('screen-settings')), findsOneWidget);
    });
  });
}

class _EnLocaleController extends LocaleController {
  @override
  Locale build() => const Locale('en');
}
