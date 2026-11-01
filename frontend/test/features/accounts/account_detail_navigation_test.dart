import 'package:bastide/app.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/core/widgets/app_shell.dart';
import 'package:bastide/features/accounts/application/account_detail_controller.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/application/settlement_rule_controller.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';
import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend.dart';
import 'account_overview_fixtures.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

void main() {
  test('a destination covers the pages beneath it', () {
    expect(isWithinDestination('/accounts', '/accounts'), isTrue);
    expect(isWithinDestination('/accounts/acc-1', '/accounts'), isTrue);
    expect(isWithinDestination('/accountsx', '/accounts'), isFalse);
    expect(isWithinDestination('/dashboard', '/accounts'), isFalse);
  });

  testWidgets('an account card opens its detail inside « Comptes »', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendControllerProvider.overrideWith(ReadyBackendController.new),
          authControllerProvider.overrideWith(
            () => FakeAuthController(initialUser: _user),
          ),
          accountsControllerProvider.overrideWith(
            () => FakeAccountsController(
              initialAccounts: [accountFrom(accountJson())],
            ),
          ),
          cardSettlementStatusProvider.overrideWith((ref) async => const []),
          accountOverviewProvider.overrideWith(
            (ref, id) async => overviewFrom(checkingOverviewJson()),
          ),
          recentAccountTransactionsProvider.overrideWith(
            (ref, id) async => const [],
          ),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comptes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountCard-acc-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen-account-detail')), findsOneWidget);
    // The top bar names the account, under a link back to the list…
    expect(
      find.descendant(
        of: find.byKey(const Key('accountDetailTitle')),
        matching: find.text('Compte courant'),
      ),
      findsOneWidget,
    );
    // …and the sidebar keeps « Comptes » selected.
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountDetailBack')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen-accounts')), findsOneWidget);
  });

  group('top bar actions', () {
    Future<FakeAccountsController> openDetail(
      WidgetTester tester, {
      required String accountId,
    }) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final accounts = FakeAccountsController(
        initialAccounts: [
          accountFrom(accountJson()),
          accountFrom(cardOverviewJson()['account'] as Map<String, dynamic>),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendControllerProvider.overrideWith(ReadyBackendController.new),
            authControllerProvider.overrideWith(
              () => FakeAuthController(initialUser: _user),
            ),
            accountsControllerProvider.overrideWith(() => accounts),
            cardSettlementStatusProvider.overrideWith((ref) async => const []),
            accountOverviewProvider.overrideWith(
              (ref, id) async => overviewFrom(
                id == 'card-1' ? cardOverviewJson() : checkingOverviewJson(),
              ),
            ),
            recentAccountTransactionsProvider.overrideWith(
              (ref, id) async => const [],
            ),
          ],
          child: const BastideApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comptes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('accountCard-$accountId')));
      await tester.pumpAndSettle();
      return accounts;
    }

    testWidgets('« Archiver » sits next to « Modifier », with no overflow', (
      tester,
    ) async {
      await openDetail(tester, accountId: 'acc-1');

      final archive = find.byKey(const Key('accountDetailArchive'));
      expect(find.byKey(const Key('accountDetailEdit')), findsOneWidget);
      expect(
        find.descendant(of: archive, matching: find.text('Archiver')),
        findsOneWidget,
      );
      // Nothing is left for an overflow to hold on a checking account.
      expect(find.byKey(const Key('accountDetailMore')), findsNothing);
    });

    testWidgets('archiving asks first, then leaves for the list', (
      tester,
    ) async {
      final accounts = await openDetail(tester, accountId: 'acc-1');

      await tester.tap(find.byKey(const Key('accountDetailArchive')));
      await tester.pumpAndSettle();

      expect(find.text('Archiver ce compte ?'), findsOneWidget);
      expect(accounts.archiveCalls, isEmpty);

      await tester.tap(find.byKey(const Key('accountArchiveConfirmButton')));
      await tester.pumpAndSettle();

      expect(accounts.archiveCalls, ['acc-1']);
      expect(find.byKey(const Key('screen-accounts')), findsOneWidget);
    });

    testWidgets('cancelling the question keeps the account', (tester) async {
      final accounts = await openDetail(tester, accountId: 'acc-1');

      await tester.tap(find.byKey(const Key('accountDetailArchive')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(accounts.archiveCalls, isEmpty);
      expect(find.byKey(const Key('screen-account-detail')), findsOneWidget);
    });

    testWidgets('a card keeps its settlement rule in the overflow', (
      tester,
    ) async {
      await openDetail(tester, accountId: 'card-1');

      expect(find.byKey(const Key('accountDetailArchive')), findsOneWidget);
      await tester.tap(find.byKey(const Key('accountDetailMore')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('accountDetailSettlementRule')),
        findsOneWidget,
      );
      // Archive is in the top bar now, not repeated in the menu.
      expect(find.text('Archiver'), findsOneWidget);
    });
  });
}
