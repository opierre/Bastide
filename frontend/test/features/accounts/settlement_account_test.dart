import 'package:bastide/features/accounts/application/settlement_account.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:flutter_test/flutter_test.dart';

// Invented accounts only — see the root CLAUDE.md on real data.
Account _account(
  String id,
  AccountType type, {
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
  test('linkableCards keeps only open deferred cards with no settlement', () {
    final cards = linkableCards([
      _account('checking', AccountType.checking),
      _account('unlinked', AccountType.deferredCard),
      _account('linked', AccountType.deferredCard, settlementAccountId: 'x'),
      _account('archived', AccountType.deferredCard, archived: true),
    ]);

    expect(cards.map((card) => card.id), ['unlinked']);
  });
}
