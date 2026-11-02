import 'package:bastide/app.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_accounts_controller.dart';
import 'support/fake_auth_controller.dart';
import 'support/fake_backend.dart';

/// The stories that need the whole app: the router behind the shell and the
/// user menu's effects on the session. The chrome's own layout is tested on
/// `AppShell` alone, in `test/core/app_shell_test.dart`.

const _signedInUser = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

/// The frame is specified at 1440×900 (docs/design/00 §Layout invariant), and
/// the top bar's contextual controls are sized for it. Testing the chrome at
/// flutter_test's default 800×600 would assert against a window size the design
/// does not target.
void _useDesignViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late FakeAuthController auth;

  Future<void> pumpApp(WidgetTester tester) async {
    _useDesignViewport(tester);
    auth = FakeAuthController(initialUser: _signedInUser);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

  testWidgets('tapping a nav item swaps the content region, not the chrome', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('screen-dashboard')), findsOneWidget);

    await tester.tap(find.text('Comptes'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen-accounts')), findsOneWidget);
    expect(find.byKey(const Key('screen-dashboard')), findsNothing);
    expect(find.byKey(const Key('appNavRail')), findsOneWidget);
    expect(find.byKey(const Key('appTopBar')), findsOneWidget);
  });

  group('user menu', () {
    Future<void> choose(WidgetTester tester, String itemKey) async {
      await tester.tap(find.byKey(const Key('userMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(itemKey)));
      await tester.pumpAndSettle();
    }

    testWidgets('log out ends the session and returns to the login screen', (
      tester,
    ) async {
      await pumpApp(tester);

      await choose(tester, 'userMenuLogoutItem');

      expect(auth.logoutCallCount, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('appTopBar')), findsNothing);
    });

    testWidgets('edit profile opens Paramètres on the Profil section', (
      tester,
    ) async {
      await pumpApp(tester);

      await choose(tester, 'userMenuEditProfileItem');

      expect(find.byKey(const Key('screen-settings')), findsOneWidget);
      expect(find.byKey(const Key('settingsRecoveryCard')), findsOneWidget);
    });

    testWidgets('edit profile switches section when already in Paramètres', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Paramètres'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settingsRecoveryCard')), findsNothing);

      await choose(tester, 'userMenuEditProfileItem');

      expect(find.byKey(const Key('settingsRecoveryCard')), findsOneWidget);
    });

    testWidgets('the request is spent: a later visit opens on the default', (
      tester,
    ) async {
      await pumpApp(tester);
      await choose(tester, 'userMenuEditProfileItem');

      await tester.tap(find.text('Comptes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paramètres'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsRecoveryCard')), findsNothing);
      expect(find.byKey(const Key('settingsCurrencyField')), findsOneWidget);
    });
  });
}
