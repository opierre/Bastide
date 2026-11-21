import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/accounts/application/account_detail_controller.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/presentation/account_detail_screen.dart';
import 'package:bastide/features/imports/application/imports_controller.dart';
import 'package:bastide/features/imports/presentation/imports_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_accounts_controller.dart';
import 'account_overview_fixtures.dart';

void main() {
  testWidgets('« dernier import » opens Imports on this account alone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1188, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/accounts/acc-1',
      routes: [
        GoRoute(
          path: '/accounts/:accountId',
          builder: (context, state) => Scaffold(
            body: AccountDetailScreen(
              accountId: state.pathParameters['accountId']!,
            ),
          ),
        ),
        // The real panel is not under test: a stand-in that marks the arrival.
        GoRoute(
          path: ImportsScreen.path,
          builder: (context, state) =>
              const Scaffold(body: SizedBox(key: Key('importsReached'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsControllerProvider.overrideWith(
            () => FakeAccountsController(
              initialAccounts: [accountFrom(accountJson())],
            ),
          ),
          accountOverviewProvider.overrideWith(
            (ref, id) async => overviewFrom(checkingOverviewJson()),
          ),
          recentAccountTransactionsProvider.overrideWith(
            (ref, id) async => const [],
          ),
        ],
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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountDetailScreen)),
    );
    expect(container.read(importHistoryAccountProvider), isNull);

    await tester.tap(find.byKey(const Key('accountDetailLastImport')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importsReached')), findsOneWidget);
    expect(
      container.read(importHistoryAccountProvider),
      const ImportHistoryAccountFilter(id: 'acc-1', name: 'Compte courant'),
    );
  });
}
