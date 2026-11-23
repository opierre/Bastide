import 'dart:async';

import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/application/accounts_layout.dart';
import 'package:bastide/features/accounts/application/settlement_rule_controller.dart';
import 'package:bastide/features/accounts/data/accounts_layout_store.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/domain/card_settlement_status.dart';
import 'package:bastide/features/accounts/presentation/accounts_screen.dart';
import 'package:bastide/features/accounts/presentation/accounts_top_bar_actions.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';

// Invented figures only — see the root CLAUDE.md on real data.

final _now = DateTime(2026, 5, 20, 10, 30);

const _user = AuthUser(
  id: 'u1',
  email: 'amelie@example.com',
  displayName: 'Amélie',
  locale: 'fr',
  currency: 'EUR',
);

Account _account({
  String id = 'a1',
  String name = 'Compte courant',
  AccountType type = AccountType.checking,
  String institution = 'Banque Exemple',
  int balanceMinor = 123456,
  DateTime? lastImportAt,
  int monthChangeMinor = 0,
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
  lastImportAt: lastImportAt,
  monthChangeMinor: monthChangeMinor,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

/// An in-memory [AccountsLayoutStore], per user like the real one.
class _MemoryLayoutStore implements AccountsLayoutStore {
  final groupings = <String, String>{};
  final collapsed = <String, List<String>>{};

  @override
  Future<String?> readGrouping(String userId) async => groupings[userId];

  @override
  Future<void> writeGrouping(String userId, String grouping) async =>
      groupings[userId] = grouping;

  @override
  Future<List<String>?> readCollapsed(String userId) async => collapsed[userId];

  @override
  Future<void> writeCollapsed(String userId, List<String> sectionIds) async =>
      collapsed[userId] = sectionIds;
}

Widget _wrap({
  required FakeAccountsController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  List<CardSettlementIssue> settlements = const [],
  AccountsLayoutStore? store,
}) {
  return ProviderScope(
    overrides: [
      accountsControllerProvider.overrideWith(() => controller),
      cardSettlementStatusProvider.overrideWith((ref) async => settlements),
      currentUserProvider.overrideWithValue(_user),
      accountsLayoutStoreProvider.overrideWithValue(
        store ?? _MemoryLayoutStore(),
      ),
      accountsClockProvider.overrideWithValue(() => _now),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The title-bar controls ride along in a 48 px row, as the shell
      // places them.
      home: const Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: AppSizes.titleBar,
              child: Row(children: [Spacer(), AccountsTopBarActions()]),
            ),
            Expanded(child: AccountsScreen()),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

String _eur(int minor, String locale) =>
    formatAmount(amountMinor: minor, currency: 'EUR', locale: locale);

/// A mixed list: two checking accounts at two banks, a savings account, an
/// unlinked deferred card and a cash wallet.
List<Account> _mixed() => [
  _account(balanceMinor: 300000, institution: 'Banque Exemple'),
  _account(
    id: 'a2',
    name: 'Livret',
    type: AccountType.savings,
    institution: 'Caisse Locale',
    balanceMinor: 600000,
  ),
  _account(
    id: 'a3',
    name: 'Joint',
    institution: 'Caisse Locale',
    balanceMinor: 100000,
  ),
  _account(
    id: 'c1',
    name: 'Carte ••4821',
    type: AccountType.deferredCard,
    institution: 'Banque Exemple',
    balanceMinor: -20000,
  ),
  _account(
    id: 'w1',
    name: 'Porte-monnaie',
    type: AccountType.cash,
    institution: '',
    balanceMinor: 5000,
  ),
];

void main() {
  group('total line', () {
    testWidgets('a deferred card stays out of the total, as from net worth', (
      tester,
    ) async {
      await _pump(
        tester,
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

      final total = tester.widget<AmountText>(
        find.byKey(const Key('accountsTotalBalance')),
      );
      expect(total.amountMinor, 100000);
      expect(total.colorize, isFalse);
    });

    for (final (locale, caption) in [
      ('fr', '2 comptes · soldes recalculés à l’instant'),
      ('en', '2 accounts · balances recalculated just now'),
    ]) {
      testWidgets('counts every account and says when ($locale)', (
        tester,
      ) async {
        await _pump(
          tester,
          _wrap(
            locale: Locale(locale),
            controller: FakeAccountsController(
              initialAccounts: [
                _account(),
                _account(id: 'a2', name: 'Livret'),
              ],
            ),
          ),
        );

        expect(find.text(caption), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('accountsTotalBalance')),
            matching: find.text(_eur(246912, locale)),
          ),
          findsOneWidget,
        );
      });
    }
  });

  testWidgets('a card without its settlement account says so above the list', (
    tester,
  ) async {
    await _pump(
      tester,
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

    expect(find.byKey(const Key('cardSettlementWarning-c1')), findsOneWidget);
    expect(find.text('Choisir le compte'), findsOneWidget);
  });

  group('by type', () {
    testWidgets('one section per type with an account, in the fixed order', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(controller: FakeAccountsController(initialAccounts: _mixed())),
      );

      final ids = [
        'type:checking',
        'type:savings',
        'type:deferredCard',
        'type:other',
      ];
      final tops = [
        for (final id in ids)
          tester.getTopLeft(find.byKey(Key('accountSectionHeader-$id'))).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(
        find.byKey(const Key('accountSectionHeader-type:credit')),
        findsNothing,
      );
      expect(find.text('Comptes courants'), findsOneWidget);
      expect(find.text('Épargne'), findsOneWidget);
      expect(find.text('Cartes à débit différé'), findsOneWidget);
      expect(find.text('Autres'), findsOneWidget);
    });

    testWidgets('a section shows its subtotal and its share of the total', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(controller: FakeAccountsController(initialAccounts: _mixed())),
      );

      // Positive subtotals: 4 000 + 6 000 + 50 = 10 050.
      final checking = tester.widget<AmountText>(
        find.byKey(const Key('accountSectionSubtotal-type:checking')),
      );
      expect(checking.amountMinor, 400000);
      expect(checking.colorize, isFalse);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('accountSectionShare-type:checking')),
            )
            .data,
        '39,8\u00A0% du total',
      );
      // A negative group reads its share in absolute value.
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('accountSectionShare-type:deferredCard')),
            )
            .data,
        '2,0\u00A0% du total',
      );
    });

    testWidgets('shares and subtotals line up in columns across headers', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(controller: FakeAccountsController(initialAccounts: _mixed())),
      );

      // Names of different lengths must not shift the right-hand figures.
      const ids = [
        'type:checking',
        'type:savings',
        'type:deferredCard',
        'type:other',
      ];
      double rightOf(String key) => tester.getTopRight(find.byKey(Key(key))).dx;
      final headerRight = rightOf('accountSectionHeader-type:checking');
      for (final id in ids) {
        expect(rightOf('accountSectionHeader-$id'), headerRight);
        // Flush right: only the bar's border and padding after the subtotal.
        expect(
          rightOf('accountSectionSubtotal-$id'),
          headerRight - 1 - AppAccountSection.headerPaddingX,
        );
        // The share ends just before the subtotal's slot.
        expect(
          rightOf('accountSectionShare-$id'),
          headerRight -
              1 -
              AppAccountSection.headerPaddingX -
              AppAccountSection.subtotalWidth -
              AppSpacing.md,
        );
      }
    });

    testWidgets('a row shows its import, its month change and its balance', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          controller: FakeAccountsController(
            initialAccounts: [
              _account(
                lastImportAt: DateTime(2026, 5, 14, 9),
                monthChangeMinor: 61205,
              ),
              _account(id: 'a2', name: 'Découvert', balanceMinor: -4500),
            ],
          ),
        ),
      );

      expect(find.text('Variation en mai'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('accountLastImport-a1'))).data,
        '14\u00A0mai 2026',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('accountLastImport-a2'))).data,
        '—',
      );
      final change = tester.widget<AmountText>(
        find.byKey(const Key('accountMonthChange-a1')),
      );
      expect(change.showPositiveSign, isTrue);
      expect(change.colorize, isTrue);
      // No movement this month: neutral, tertiary.
      final still = tester.widget<AmountText>(
        find.byKey(const Key('accountMonthChange-a2')),
      );
      expect(still.style?.color, AppColors.dark.textTertiary);
      // A balance is neutral, and `negative` only below zero.
      expect(
        tester
            .widget<AmountText>(find.byKey(const Key('accountBalance-a1')))
            .style
            ?.color,
        isNull,
      );
      expect(
        tester
            .widget<AmountText>(find.byKey(const Key('accountBalance-a2')))
            .style
            ?.color,
        AppColors.dark.negative,
      );
      expect(find.text(_eur(-4500, 'fr')), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await _pump(
        tester,
        _wrap(
          locale: const Locale('en'),
          controller: FakeAccountsController(
            initialAccounts: [_account(lastImportAt: DateTime(2026, 5, 14))],
          ),
        ),
      );

      expect(find.text('Current accounts'), findsOneWidget);
      expect(find.text('Change in May'), findsOneWidget);
      expect(find.text('100.0% of total'), findsOneWidget);
      expect(find.text('May\u00A014, 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('collapsing', () {
    testWidgets('every section is open on a first visit', (tester) async {
      await _pump(
        tester,
        _wrap(controller: FakeAccountsController(initialAccounts: _mixed())),
      );

      expect(
        find.byKey(const Key('accountSectionOpen-type:checking')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accountRow-a1')), findsOneWidget);
    });

    testWidgets('the header toggles the section and the choice is kept', (
      tester,
    ) async {
      final store = _MemoryLayoutStore();
      await _pump(
        tester,
        _wrap(
          controller: FakeAccountsController(initialAccounts: _mixed()),
          store: store,
        ),
      );

      await tester.tap(
        find.byKey(const Key('accountSectionHeader-type:checking')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('accountSectionClosed-type:checking')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accountRow-a1')), findsNothing);
      expect(find.byKey(const Key('accountRow-a2')), findsOneWidget);
      expect(store.collapsed['u1'], ['type:checking']);

      await tester.tap(
        find.byKey(const Key('accountSectionHeader-type:checking')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('accountRow-a1')), findsOneWidget);
      expect(store.collapsed['u1'], isEmpty);
    });

    testWidgets('a section closed on a previous visit opens closed', (
      tester,
    ) async {
      final store = _MemoryLayoutStore()..collapsed['u1'] = ['type:savings'];
      await _pump(
        tester,
        _wrap(
          controller: FakeAccountsController(initialAccounts: _mixed()),
          store: store,
        ),
      );

      expect(find.byKey(const Key('accountRow-a2')), findsNothing);
      expect(find.byKey(const Key('accountRow-a1')), findsOneWidget);
    });
  });

  group('by institution', () {
    testWidgets('the switch regroups by institution and is remembered', (
      tester,
    ) async {
      final store = _MemoryLayoutStore();
      await _pump(
        tester,
        _wrap(
          controller: FakeAccountsController(initialAccounts: _mixed()),
          store: store,
        ),
      );

      await tester.tap(find.byKey(const Key('accountsGroupingByInstitution')));
      await tester.pumpAndSettle();

      expect(store.groupings['u1'], 'institution');
      // By descending subtotal, « Sans établissement » last.
      final ids = [
        'institution:Caisse Locale',
        'institution:Banque Exemple',
        'institution:',
      ];
      final tops = [
        for (final id in ids)
          tester.getTopLeft(find.byKey(Key('accountSectionHeader-$id'))).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.text('Sans établissement'), findsOneWidget);
    });

    testWidgets('the switch is as tall as the other title-bar controls', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(controller: FakeAccountsController(initialAccounts: _mixed())),
      );

      final switchSize = tester.getSize(
        find.byKey(const Key('accountsGroupingSwitch')),
      );
      expect(switchSize.height, AppSizes.button);
      expect(
        tester.getSize(find.byKey(const Key('addAccountButton'))).height,
        switchSize.height,
      );
    });

    testWidgets('a remembered grouping is restored', (tester) async {
      final store = _MemoryLayoutStore()..groupings['u1'] = 'institution';
      await _pump(
        tester,
        _wrap(
          controller: FakeAccountsController(initialAccounts: _mixed()),
          store: store,
        ),
      );

      expect(
        find.byKey(const Key('accountSectionHeader-institution:Caisse Locale')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('accountSectionHeader-type:checking')),
        findsNothing,
      );
    });
  });

  group('states', () {
    testWidgets('loading shows the total line and three header silhouettes', (
      tester,
    ) async {
      final pending = Completer<List<Account>>();
      await tester.pumpWidget(
        _wrap(controller: _PendingAccountsController(pending.future)),
      );
      await tester.pump();

      expect(find.byKey(const Key('accountsLoadingIndicator')), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('accountsLoadingSection-$i')), findsOneWidget);
      }
      pending.complete(const []);
      await tester.pumpAndSettle();
    });

    for (final (locale, title, imports) in [
      ('fr', 'Ajoutez votre premier compte', 'Aller aux imports'),
      ('en', 'Add your first account', 'Go to imports'),
    ]) {
      testWidgets('the empty state offers to add or import ($locale)', (
        tester,
      ) async {
        await _pump(
          tester,
          _wrap(controller: FakeAccountsController(), locale: Locale(locale)),
        );

        expect(find.text(title), findsOneWidget);
        expect(
          find.byKey(const Key('emptyStateAddAccountButton')),
          findsOneWidget,
        );
        expect(find.text(imports), findsOneWidget);
        expect(find.byKey(const Key('accountsList')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders in the light theme', (tester) async {
      await _pump(
        tester,
        _wrap(
          theme: AppTheme.light,
          controller: FakeAccountsController(
            initialAccounts: [
              _account(),
              _account(id: 'a2', balanceMinor: -4500),
            ],
          ),
        ),
      );

      expect(
        tester
            .widget<AmountText>(find.byKey(const Key('accountBalance-a2')))
            .style
            ?.color,
        AppColors.light.negative,
      );
      expect(tester.takeException(), isNull);
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
      _account(
        id: 'c3',
        name: 'Carte ••5902',
        type: AccountType.credit,
        balanceMinor: -2500,
      ),
    ];

    testWidgets('a linked card has no row, an unlinked card keeps its own', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          controller: FakeAccountsController(initialAccounts: withTwoCards()),
        ),
      );

      expect(find.byKey(const Key('accountRow-a1')), findsOneWidget);
      expect(find.byKey(const Key('accountRow-c1')), findsNothing);
      expect(find.byKey(const Key('accountRow-c2')), findsNothing);
      expect(find.byKey(const Key('accountRow-c3')), findsOneWidget);
      // The total and the count still include them.
      expect(
        find.text('4 comptes · soldes recalculés à l’instant'),
        findsOneWidget,
      );
    });

    for (final (locale, count, edit, rule, archive) in [
      ('fr', '2 cartes', 'Modifier', 'Règle de prélèvement', 'Archiver'),
      ('en', '2 cards', 'Edit', 'Settlement rule', 'Archive'),
    ]) {
      testWidgets('two cards are listed with their actions ($locale)', (
        tester,
      ) async {
        await _pump(
          tester,
          _wrap(
            controller: FakeAccountsController(initialAccounts: withTwoCards()),
            locale: Locale(locale),
          ),
        );

        final button = find.byKey(const Key('accountLinkedCards-a1'));
        expect(
          find.descendant(of: button, matching: find.text(count)),
          findsOneWidget,
        );

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('linkedCard-c1')), findsOneWidget);
        expect(find.byKey(const Key('linkedCard-c2')), findsOneWidget);

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
        expect(
          find.byKey(const Key('linkedCardSettlementRule-c2')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('archiving a card from the menu archives that card', (
      tester,
    ) async {
      final controller = FakeAccountsController(
        initialAccounts: withTwoCards(),
      );
      await _pump(tester, _wrap(controller: controller));

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

    testWidgets('one card reads in the singular; none shows nothing', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          controller: FakeAccountsController(
            initialAccounts: [
              _account(),
              _account(id: 'a2', name: 'Livret', type: AccountType.savings),
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

      expect(find.text('1 carte'), findsOneWidget);
      expect(find.byKey(const Key('accountLinkedCards-a2')), findsNothing);
    });
  });
}

/// A list that has not arrived yet.
class _PendingAccountsController extends FakeAccountsController {
  _PendingAccountsController(this._pending);

  final Future<List<Account>> _pending;

  @override
  Future<List<Account>> build() => _pending;
}
