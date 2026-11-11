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
  group('settlementCandidates', () {
    test('offers only open current accounts, never the card itself', () {
      final candidates = settlementCandidates([
        _account('checking', AccountType.checking),
        _account('savings', AccountType.savings),
        _account('credit', AccountType.credit),
        _account('cash', AccountType.cash),
        _account('other', AccountType.other),
        _account('card', AccountType.deferredCard),
        _account('other-card', AccountType.deferredCard),
        _account('closed', AccountType.checking, archived: true),
      ], cardId: 'card');

      expect(candidates.map((account) => account.id), ['checking']);
    });

    test("keeps the card's saved settlement account whatever its type", () {
      final candidates = settlementCandidates([
        _account('checking', AccountType.checking),
        _account('savings', AccountType.savings),
        _account('cash', AccountType.cash),
      ], currentId: 'savings');

      expect(candidates.map((account) => account.id), ['checking', 'savings']);
    });
  });

  group('proposedSettlementAccountId', () {
    test('preselects the only current account once savings are left out', () {
      final candidates = settlementCandidates([
        _account('checking', AccountType.checking),
        _account('savings', AccountType.savings),
      ]);

      expect(
        proposedSettlementAccountId(candidates, institution: 'Autre Banque'),
        'checking',
      );
    });

    test('leaves the choice open with two current accounts elsewhere', () {
      final candidates = settlementCandidates([
        _account('checking-1', AccountType.checking),
        _account('checking-2', AccountType.checking),
      ]);

      expect(
        proposedSettlementAccountId(candidates, institution: 'Autre Banque'),
        isNull,
      );
    });
  });

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
