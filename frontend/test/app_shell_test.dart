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

void main() {
  testWidgets('shell renders the fixed nav, top and bottom bars', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _authenticatedOverrides, child: const FinStrideApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appNavRail')), findsOneWidget);
    expect(find.byKey(const Key('appTopBar')), findsOneWidget);
    expect(find.byKey(const Key('appBottomBar')), findsOneWidget);
    expect(find.byKey(const Key('screen-dashboard')), findsOneWidget);
  });

  testWidgets('tapping a nav item swaps the content region, not the chrome', (
    tester,
  ) async {
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
    expect(find.byKey(const Key('appBottomBar')), findsOneWidget);
  });

  testWidgets('renders under fr without missing localized keys', (
    tester,
  ) async {
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
