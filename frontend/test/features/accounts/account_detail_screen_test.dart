import 'dart:async';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/accounts/application/account_detail_controller.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/application/settlement_rule_controller.dart';
import 'package:bastide/features/accounts/domain/account_overview.dart';
import 'package:bastide/features/accounts/domain/settlement_rule.dart';
import 'package:bastide/features/accounts/presentation/account_detail_screen.dart';
import 'package:bastide/features/accounts/presentation/cycle_bars.dart';
import 'package:bastide/features/accounts/presentation/settlement_rule_dialog.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';
import 'account_overview_fixtures.dart';

Transaction _transaction(String id, int amountMinor) => Transaction(
  id: id,
  accountId: 'acc-1',
  bookedDate: DateTime(2026, 10, 29),
  valueDate: null,
  amountMinor: amountMinor,
  currency: 'EUR',
  descriptionRaw: 'PRLV BOX INTERNET',
  descriptionClean: 'Box Internet',
  memo: null,
  merchant: null,
  category: null,
  categorizationSource: CategorizationSource.uncategorized,
  categorizationConfidence: null,
  needsReview: true,
  fitid: null,
  dedupHash: 'h-$id',
  createdAt: DateTime.utc(2026, 10, 30),
  updatedAt: DateTime.utc(2026, 10, 30),
);

Widget _wrap({
  required String accountId,
  FutureOr<AccountOverview> Function()? overview,
  List<Transaction> transactions = const [],
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    // A failed read surfaces at once rather than after Riverpod's retries.
    retry: (_, _) => null,
    overrides: [
      accountsControllerProvider.overrideWith(
        () => FakeAccountsController(
          initialAccounts: [
            accountFrom(accountJson()),
            accountFrom(
              accountJson(
                id: 'card-2',
                name: 'Carte Business',
                type: 'deferred_card',
                settlementAccountId: 'acc-1',
              ),
            ),
          ],
        ),
      ),
      accountOverviewProvider.overrideWith(
        (ref, id) async =>
            overview == null ? Completer<AccountOverview>().future : overview(),
      ),
      recentAccountTransactionsProvider.overrideWith(
        (ref, id) async => transactions,
      ),
      settlementRuleProvider(
        'card-2',
      ).overrideWith((ref) async => const SettlementRuleState()),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AccountDetailScreen(accountId: accountId)),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  // The content region beside the 252px sidebar, at the 1440px design width.
  tester.view.physicalSize = const Size(1188, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a checking account shows its balance, stats and cards', (
    tester,
  ) async {
    await _pump(
      tester,
      _wrap(
        accountId: 'acc-1',
        overview: () => overviewFrom(checkingOverviewJson()),
        transactions: [_transaction('t1', -2999)],
      ),
    );

    expect(find.text('Solde actuel'.toUpperCase()), findsOneWidget);
    expect(find.byKey(const Key('accountDetailBalanceChart')), findsOneWidget);
    expect(find.text('Variation sur 12 mois'), findsOneWidget);
    // Four month-ends rising in a row: said, because it is true.
    expect(
      find.text('Votre solde progresse depuis 4 mois consécutifs.'),
      findsOneWidget,
    );
    expect(find.text('Cartes rattachées'), findsOneWidget);
    expect(find.text('Visa Premier'), findsOneWidget);
    expect(find.text('•••• 4821'), findsOneWidget);
    // The second card has no rule: the chip offers the fix; the first does not.
    expect(
      find.byKey(const Key('accountDetailRuleMissing-card-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('accountDetailRuleMissing-card-1')),
      findsNothing,
    );
    expect(find.text('Prélèvement non planifié'), findsOneWidget);
    expect(find.byKey(const Key('transactionRow-t1')), findsOneWidget);
  });

  testWidgets('no streak line under two rises', (tester) async {
    final json = checkingOverviewJson();
    (json['period'] as Map<String, dynamic>)['consecutive_rising_months'] = 1;

    await _pump(
      tester,
      _wrap(accountId: 'acc-1', overview: () => overviewFrom(json)),
    );

    expect(find.byKey(const Key('accountDetailStreak')), findsNothing);
  });

  testWidgets('the missing-rule chip opens the settlement rule dialog', (
    tester,
  ) async {
    await _pump(
      tester,
      _wrap(
        accountId: 'acc-1',
        overview: () => overviewFrom(checkingOverviewJson()),
      ),
    );

    await tester.tap(find.byKey(const Key('accountDetailRuleMissing-card-2')));
    await tester.pumpAndSettle();

    expect(find.byType(SettlementRuleDialog), findsOneWidget);
  });

  testWidgets('a deferred card shows its cycles and settlement account', (
    tester,
  ) async {
    await _pump(
      tester,
      _wrap(
        accountId: 'card-1',
        overview: () => overviewFrom(cardOverviewJson()),
      ),
    );

    expect(find.text('Encours du cycle'.toUpperCase()), findsOneWidget);
    expect(find.byKey(const Key('accountDetailCycleChart')), findsOneWidget);
    expect(find.byKey(const Key('accountDetailBalanceChart')), findsNothing);
    expect(find.text('Compte de règlement'), findsOneWidget);
    expect(
      find.byKey(const Key('accountDetailPayingAccount-acc-1')),
      findsOneWidget,
    );
    expect(find.textContaining('CARTE X4821'), findsOneWidget);
    expect(find.text('Moyenne par cycle'), findsOneWidget);
    expect(
      find.text('Vos dépenses par carte baissent depuis 2 cycles.'),
      findsOneWidget,
    );
    expect(find.text('Cartes rattachées'), findsNothing);
  });

  testWidgets('a card cycle chart follows the 6/12/all switch', (tester) async {
    final json = cardOverviewJson();
    final settlement = json['card_settlement'] as Map<String, dynamic>;
    // Twenty cycles: nineteen settled, then the open one.
    final cycles = [
      for (var month = 1; month <= 19; month++)
        {
          'settled_on': DateTime(
            2025,
            month,
            5,
          ).toIso8601String().substring(0, 10),
          'amount_minor': -50000 - month * 100,
        },
      {'settled_on': null, 'amount_minor': -12000},
    ];
    await _pump(
      tester,
      _wrap(
        accountId: 'card-1',
        overview: () => overviewFrom({
          ...json,
          'card_settlement': {...settlement, 'cycles': cycles},
        }),
      ),
    );
    int bars() =>
        tester.widget<CycleBars>(find.byType(CycleBars)).values.length;

    expect(bars(), 12);

    await tester.tap(find.byKey(const Key('accountDetailRange-six')));
    await tester.pumpAndSettle();
    expect(bars(), 6);

    await tester.tap(find.byKey(const Key('accountDetailRange-all')));
    await tester.pumpAndSettle();
    expect(bars(), 20);
  });

  testWidgets('a fresh account says what comes next, never hides a section', (
    tester,
  ) async {
    await _pump(
      tester,
      _wrap(
        accountId: 'acc-new',
        overview: () => overviewFrom(freshOverviewJson()),
      ),
    );

    expect(find.byKey(const Key('accountDetailChartEmpty')), findsOneWidget);
    expect(find.text('Importer un relevé'), findsOneWidget);
    expect(find.text('Pas encore d’opérations'), findsOneWidget);
    expect(find.text('Aucun import pour l’instant'), findsOneWidget);
    expect(find.byKey(const Key('accountDetailNoCards')), findsOneWidget);
    expect(
      find.byKey(const Key('accountDetailNoTransactions')),
      findsOneWidget,
    );
    expect(find.text('—'), findsNWidgets(3));
    expect(find.byKey(const Key('accountDetailStreak')), findsNothing);
  });

  testWidgets('loading shows the skeleton', (tester) async {
    await _pump(tester, _wrap(accountId: 'acc-1'));

    expect(find.byKey(const Key('accountDetailLoading')), findsOneWidget);
    expect(find.byKey(const Key('accountDetailIdentity')), findsNothing);
  });

  testWidgets('a failed read offers a retry', (tester) async {
    await _pump(
      tester,
      _wrap(
        accountId: 'acc-1',
        overview: () => Future<AccountOverview>.error(Exception('boom')),
      ),
    );

    expect(find.byKey(const Key('accountDetailRetryButton')), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('renders under ${locale.languageCode} without overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          accountId: 'acc-1',
          locale: locale,
          overview: () => overviewFrom(checkingOverviewJson()),
          transactions: [_transaction('t1', 284000)],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('accountDetailIdentity')), findsOneWidget);
    });
  }

  test('the route carries the account id', () {
    expect(AccountDetailScreen.location('acc-1'), '/accounts/acc-1');
    expect(AccountDetailScreen.idFromPath('/accounts/acc-1'), 'acc-1');
    expect(AccountDetailScreen.idFromPath('/accounts'), isNull);
    expect(AccountDetailScreen.idFromPath('/transactions'), isNull);
  });
}
