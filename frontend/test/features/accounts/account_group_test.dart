import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/domain/account_group.dart';
import 'package:flutter_test/flutter_test.dart';

// Invented figures only — see the root CLAUDE.md on real data.

Account _account(
  String id,
  AccountType type,
  int balanceMinor, {
  String institution = 'Banque Exemple',
}) => Account(
  id: id,
  name: id,
  type: type,
  institution: institution,
  currency: 'EUR',
  openingBalanceMinor: balanceMinor,
  balanceMinor: balanceMinor,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  test('cash and other accounts share « Autres »; credit has its own', () {
    final groups = groupAccounts([
      _account('o1', AccountType.other, 1000),
      _account('k1', AccountType.cash, 500),
      _account('l1', AccountType.credit, -30000),
    ], AccountsGrouping.byType);

    expect(groups.map((group) => group.id), ['type:credit', 'type:other']);
    expect(groups.last.accounts.map((a) => a.id), ['o1', 'k1']);
    expect(groups.last.subtotalMinor, 1500);
  });

  test('shares divide by the positive subtotals, negatives in absolute', () {
    final groups = groupAccounts([
      _account('a', AccountType.checking, 30000),
      _account('b', AccountType.savings, 10000),
      _account('c', AccountType.deferredCard, -4000),
    ], AccountsGrouping.byType);

    expect(groups.map((group) => group.sharePercent), [75, 25, 10]);
  });

  test('no positive subtotal leaves every share at zero', () {
    final groups = groupAccounts([
      _account('c', AccountType.credit, -4000),
    ], AccountsGrouping.byType);

    expect(groups.single.sharePercent, 0);
  });

  test('institutions are trimmed, ranked by subtotal, the unnamed last', () {
    final groups = groupAccounts([
      _account('a', AccountType.checking, 100, institution: ''),
      _account('b', AccountType.checking, 200, institution: 'Petite Banque '),
      _account('c', AccountType.savings, 900, institution: 'Grande Banque'),
      _account('d', AccountType.savings, 50, institution: 'Petite Banque'),
    ], AccountsGrouping.byInstitution);

    expect(groups.map((group) => group.id), [
      'institution:Grande Banque',
      'institution:Petite Banque',
      'institution:',
    ]);
    expect(groups[1].subtotalMinor, 250);
    expect(groups.last.hasNoInstitution, isTrue);
  });

  test('an unknown stored grouping falls back to by type', () {
    expect(AccountsGrouping.fromStorage('nope'), AccountsGrouping.byType);
    expect(
      AccountsGrouping.fromStorage('institution'),
      AccountsGrouping.byInstitution,
    );
  });
}
