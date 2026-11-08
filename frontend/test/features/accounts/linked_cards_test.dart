import 'package:bastide/features/accounts/application/linked_cards.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account(
  String id, {
  AccountType type = AccountType.deferredCard,
  String? settlementAccountId,
  bool archived = false,
}) => Account(
  id: id,
  name: id,
  type: type,
  institution: 'Banque Exemple',
  currency: 'EUR',
  settlementAccountId: settlementAccountId,
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: archived,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  test('keeps the live cards settled from the account, in list order', () {
    final accounts = [
      _account('checking', type: AccountType.checking),
      _account('card-b', settlementAccountId: 'checking'),
      _account('other-card', settlementAccountId: 'savings'),
      _account('unlinked-card'),
      _account('old-card', settlementAccountId: 'checking', archived: true),
      _account('card-a', settlementAccountId: 'checking'),
    ];

    expect(linkedCards(accounts, 'checking').map((card) => card.id), [
      'card-b',
      'card-a',
    ]);
  });

  test('an account nothing is settled from has no cards', () {
    expect(
      linkedCards([
        _account('checking', type: AccountType.checking),
      ], 'checking'),
      isEmpty,
    );
  });

  group('panelAccounts', () {
    List<String> ids(List<Account> accounts) =>
        panelAccounts(accounts).map((account) => account.id).toList();

    test('hides the cards linked to a shown account, keeps the rest', () {
      expect(
        ids([
          _account('checking', type: AccountType.checking),
          _account('linked-card', settlementAccountId: 'checking'),
          _account('unlinked-card'),
          _account('savings', type: AccountType.savings),
        ]),
        ['checking', 'unlinked-card', 'savings'],
      );
    });

    test('keeps a card whose settlement account is not in the list', () {
      expect(
        ids([
          _account('checking', type: AccountType.checking),
          _account('orphan-card', settlementAccountId: 'gone'),
        ]),
        ['checking', 'orphan-card'],
      );
    });

    test('keeps a card whose settlement account is archived', () {
      expect(
        ids([
          _account('old', type: AccountType.checking, archived: true),
          _account('card', settlementAccountId: 'old'),
        ]),
        ['card'],
      );
    });

    test('keeps a card settled from a card that is itself hidden', () {
      expect(
        ids([
          _account('checking', type: AccountType.checking),
          _account(
            'credit',
            type: AccountType.credit,
            settlementAccountId: 'checking',
          ),
          _account('deferred', settlementAccountId: 'credit'),
        ]),
        ['checking', 'deferred'],
      );
    });

    test('a loop of links still leaves one of its accounts shown', () {
      expect(
        ids([
          _account('card-a', settlementAccountId: 'card-b'),
          _account('card-b', settlementAccountId: 'card-a'),
        ]),
        hasLength(1),
      );
      expect(ids([_account('self', settlementAccountId: 'self')]), ['self']);
    });
  });
}
