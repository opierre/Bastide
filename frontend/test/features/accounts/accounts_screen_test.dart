import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/application/settlement_rule_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/domain/card_settlement_status.dart';
import 'package:bastide/features/accounts/presentation/accounts_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../support/fake_accounts_controller.dart';

Account _account({
  String id = 'a1',
  String name = 'Compte courant',
  AccountType type = AccountType.checking,
  String institution = 'BNP Paribas',
  int balanceMinor = 123456,
  DateTime? lastTransactionDate,
  String? settlementAccountId,
}) => Account(
  id: id,
  name: name,
  type: type,
  institution: institution,
  currency: 'EUR',
  settlementAccountId: settlementAccountId,
  openingBalanceMinor: balanceMinor,
  balanceMinor: balanceMinor,
  lastTransactionDate: lastTransactionDate,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _wrap({
  required FakeAccountsController controller,
  Locale locale = const Locale('fr'),
  List<CardSettlementIssue> settlements = const [],
}) {
  return ProviderScope(
    overrides: [
      accountsControllerProvider.overrideWith(() => controller),
      cardSettlementStatusProvider.overrideWith((ref) async => settlements),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AccountsScreen()),
    ),
  );
}

/// Scoped to the grid: the screen's summary card shows the *total* balance,
/// which for a single account is the same figure — but unsigned, since a total
/// is a standing figure rather than a movement.
Finder _balanceInGrid(String formatted) => find.descendant(
  of: find.byKey(const Key('accountsList')),
  matching: find.text(formatted),
);

/// A fake whose edit lands in the list, so a test can watch the panel follow
/// a card being linked.
class _LinkingAccountsController extends FakeAccountsController {
  _LinkingAccountsController({super.initialAccounts});

  @override
  Future<void> updateAccount(
    String id, {
    required String name,
    required AccountType type,
    required String institution,
    required int openingBalanceMinor,
    String? settlementAccountId,
  }) async {
    state = AsyncData([
      for (final account in state.value ?? const <Account>[])
        if (account.id == id)
          _account(
            id: id,
            name: name,
            type: type,
            institution: institution,
            balanceMinor: openingBalanceMinor,
            settlementAccountId: settlementAccountId,
          )
        else
          account,
    ]);
  }
}

void main() {
  testWidgets('a deferred card stays out of the total, as from net worth', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeAccountsController(
          initialAccounts: [
            _account(balanceMinor: 100000),
            _account(
              id: 'c1',
              name: 'Carte',
              type: AccountType.deferredCard,
              balanceMinor: -32040,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final total = tester.widget<AmountText>(
      find.byKey(const Key('accountsTotalBalance')),
    );
    expect(total.amountMinor, 100000);
  });

  testWidgets('a card without its settlement account says so above the grid', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeAccountsController(
          initialAccounts: [
            _account(),
            _account(
              id: 'c1',
              name: 'Carte ••4821',
              type: AccountType.deferredCard,
            ),
          ],
        ),
        settlements: const [
          CardSettlementIssue(
            accountId: 'c1',
            kind: CardSettlementIssueKind.noSettlementAccount,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cardSettlementWarning-c1')), findsOneWidget);
    expect(find.text('Choisir le compte'), findsOneWidget);
  });

  for (final (locale, dated, undated) in [
    ('fr', 'Dernière opération le 29 sept. 2026', 'Aucune opération'),
    ('en', 'Last transaction on Sep 29, 2026', 'No transactions yet'),
  ]) {
    testWidgets('shows when each account last moved ($locale)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          locale: Locale(locale),
          controller: FakeAccountsController(
            initialAccounts: [
              _account(lastTransactionDate: DateTime(2026, 9, 29)),
              _account(id: 'a2', name: 'Livret A'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('accountLastTransaction-a1')))
            .data,
        dated,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('accountLastTransaction-a2')))
            .data,
        undated,
      );
    });
  }

  testWidgets('renders the balance formatted for the fr locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeAccountsController(
          initialAccounts: [_account(balanceMinor: 123456)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // An account card's balance is its one data point, so it is signed.
    final expected =
        '+${NumberFormat.simpleCurrency(locale: 'fr', name: 'EUR').format(1234.56)}';
    expect(_balanceInGrid(expected), findsOneWidget);
  });

  testWidgets('renders the balance formatted for the en locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeAccountsController(
          initialAccounts: [_account(balanceMinor: 123456)],
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final expected =
        '+${NumberFormat.simpleCurrency(locale: 'en', name: 'EUR').format(1234.56)}';
    expect(_balanceInGrid(expected), findsOneWidget);
  });

  testWidgets('sums the listed balances into the summary card', (tester) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeAccountsController(
          initialAccounts: [
            _account(id: 'a1', balanceMinor: 123456),
            _account(id: 'a2', name: 'Livret A', balanceMinor: 76544),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final total = NumberFormat.simpleCurrency(
      locale: 'fr',
      name: 'EUR',
    ).format(2000.00);
    expect(
      find.descendant(
        of: find.byKey(const Key('accountsTotalBalance')),
        matching: find.text(total),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders the empty state with a CTA when there are no accounts', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emptyStateAddAccountButton')), findsOneWidget);
    expect(find.byKey(const Key('accountsList')), findsNothing);
  });

  testWidgets('renders under fr without missing localized keys', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
    await tester.pumpAndSettle();

    expect(find.text('Ajoutez votre premier compte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(controller: FakeAccountsController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add your first account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('card tiles', () {
    List<Account> accountsWithCards() => [
      _account(balanceMinor: 100000),
      _account(
        id: 'c1',
        name: 'Carte ••4821',
        type: AccountType.deferredCard,
        balanceMinor: -32040,
        settlementAccountId: 'a1',
      ),
      _account(
        id: 'c2',
        name: 'Carte ••7310',
        type: AccountType.credit,
        balanceMinor: -15000,
        settlementAccountId: 'a1',
      ),
      _account(
        id: 'c3',
        name: 'Carte ••5902',
        type: AccountType.credit,
        balanceMinor: -2500,
      ),
    ];

    testWidgets('a linked card has no tile, an unlinked card keeps its own', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(
            initialAccounts: accountsWithCards(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('accountCard-a1')), findsOneWidget);
      expect(find.byKey(const Key('accountCard-c1')), findsNothing);
      expect(find.byKey(const Key('accountCard-c2')), findsNothing);
      expect(find.byKey(const Key('accountCard-c3')), findsOneWidget);
      // The hidden cards are still reached from their account.
      expect(
        find.descendant(
          of: find.byKey(const Key('accountLinkedCards-a1')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hiding linked cards leaves the summary total as it was', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(
            initialAccounts: accountsWithCards(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deferred card out (its account settles it), credit cards in, whether
      // or not they have a tile: 100000 - 15000 - 2500.
      final total = tester.widget<AmountText>(
        find.byKey(const Key('accountsTotalBalance')),
      );
      expect(total.amountMinor, 82500);
    });

    testWidgets('linking a card takes its tile off the grid', (tester) async {
      final controller = _LinkingAccountsController(
        initialAccounts: [
          _account(),
          _account(id: 'c1', name: 'Carte ••4821', type: AccountType.credit),
        ],
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('accountCard-c1')), findsOneWidget);

      await controller.updateAccount(
        'c1',
        name: 'Carte ••4821',
        type: AccountType.credit,
        institution: 'BNP Paribas',
        openingBalanceMinor: 123456,
        settlementAccountId: 'a1',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('accountCard-c1')), findsNothing);
      expect(find.byKey(const Key('accountLinkedCards-a1')), findsOneWidget);
    });
  });

  group('linked cards', () {
    List<Account> withTwoCards() => [
      _account(),
      _account(
        id: 'c1',
        name: 'Carte ••4821',
        type: AccountType.deferredCard,
        settlementAccountId: 'a1',
      ),
      _account(
        id: 'c2',
        name: 'Carte ••7310',
        type: AccountType.credit,
        settlementAccountId: 'a1',
      ),
    ];

    for (final (locale, tooltip, edit, rule, archive) in [
      ('fr', '2 cartes liées', 'Modifier', 'Règle de prélèvement', 'Archiver'),
      ('en', '2 linked cards', 'Edit', 'Settlement rule', 'Archive'),
    ]) {
      testWidgets(
        'an account with two cards lists them with their actions ($locale)',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              controller: FakeAccountsController(
                initialAccounts: withTwoCards(),
              ),
              locale: Locale(locale),
            ),
          );
          await tester.pumpAndSettle();

          final button = find.byKey(const Key('accountLinkedCards-a1'));
          expect(button, findsOneWidget);
          expect(
            find.descendant(of: button, matching: find.text('2')),
            findsOneWidget,
          );
          expect(find.byTooltip(tooltip), findsOneWidget);

          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('linkedCard-c1')), findsOneWidget);
          expect(find.byKey(const Key('linkedCard-c2')), findsOneWidget);

          // A deferred card offers its settlement rule beside edit and archive.
          await tester.tap(find.byKey(const Key('linkedCard-c1')));
          await tester.pumpAndSettle();
          for (final (key, label) in [
            ('linkedCardEdit-c1', edit),
            ('linkedCardSettlementRule-c1', rule),
            ('linkedCardArchive-c1', archive),
          ]) {
            expect(
              find.descendant(
                of: find.byKey(Key(key)),
                matching: find.text(label),
              ),
              findsOneWidget,
            );
          }

          // A credit card has no settlement rule to offer.
          await tester.tap(find.byKey(const Key('linkedCard-c2')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('linkedCardEdit-c2')), findsOneWidget);
          expect(find.byKey(const Key('linkedCardArchive-c2')), findsOneWidget);
          expect(
            find.byKey(const Key('linkedCardSettlementRule-c2')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('archiving a card from the list archives that card', (
      tester,
    ) async {
      final controller = FakeAccountsController(
        initialAccounts: withTwoCards(),
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accountLinkedCards-a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('linkedCard-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('linkedCardArchive-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accountArchiveConfirmButton')));
      await tester.pumpAndSettle();

      expect(controller.archiveCalls, ['c1']);
    });

    testWidgets('an account without cards shows no card count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(initialAccounts: [_account()]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('accountLinkedCards-a1')), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });

    testWidgets('one card reads in the singular', (tester) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(
            initialAccounts: [
              _account(),
              _account(
                id: 'c1',
                name: 'Carte ••4821',
                type: AccountType.deferredCard,
                settlementAccountId: 'a1',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('1 carte liée'), findsOneWidget);
    });
  });
}
