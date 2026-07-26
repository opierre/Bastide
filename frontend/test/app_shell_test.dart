import 'package:finstride/app.dart';
import 'package:finstride/core/l10n/locale_provider.dart';
import 'package:finstride/features/accounts/application/accounts_controller.dart';
import 'package:finstride/features/auth/application/auth_controller.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_accounts_controller.dart';
import 'support/fake_auth_controller.dart';

const _signedInUser = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

final _authenticatedOverrides = [
  authControllerProvider.overrideWith(() => FakeAuthController(initialUser: _signedInUser)),
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

void main() {
  testWidgets('shell renders the fixed sidebar and top bar', (tester) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: _authenticatedOverrides, child: const FinStrideApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appNavRail')), findsOneWidget);
    expect(find.byKey(const Key('appTopBar')), findsOneWidget);
    expect(find.byKey(const Key('screen-dashboard')), findsOneWidget);
  });

  testWidgets('the privacy badge sits at the sidebar foot, not in a bottom bar', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: _authenticatedOverrides, child: const FinStrideApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appBottomBar')), findsNothing);
    expect(find.byKey(const Key('sidebarPrivacyBadge')), findsOneWidget);
  });

  testWidgets('collapsing the sidebar keeps the destinations and the lock', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: _authenticatedOverrides, child: const FinStrideApp()),
    );
    await tester.pumpAndSettle();

    double railWidth() => tester.getSize(find.byKey(const Key('appNavRail'))).width;
    expect(railWidth(), 252);

    await tester.tap(find.byKey(const Key('sidebarToggleButton')));
    await tester.pumpAndSettle();

    expect(railWidth(), 76);
    // The label is gone but the destination itself is not — the collapsed rail
    // is icon-only, never a shorter menu.
    expect(find.text('Comptes'), findsNothing);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('tapping a nav item swaps the content region, not the chrome', (
    tester,
  ) async {
    _useDesignViewport(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: _authenticatedOverrides, child: const FinStrideApp()),
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
      ProviderScope(overrides: _authenticatedOverrides, child: const FinStrideApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Comptes'), findsOneWidget);
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
          localeProvider.overrideWith(() => _EnLocaleController()),
        ],
        child: const FinStrideApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Accounts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EnLocaleController extends LocaleController {
  @override
  Locale build() => const Locale('en');
}
