import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/imports/application/import_targets.dart';
import 'package:bastide/features/imports/application/ofx_account_detection.dart';
import 'package:bastide/features/imports/domain/ofx_account_info.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account(String id) => Account(
  id: id,
  name: 'Compte $id',
  type: AccountType.checking,
  institution: 'Banque Exemple',
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

OfxAccountInfo _info(String number) => OfxAccountInfo(accountNumber: number);

void main() {
  final a1 = _account('a1');
  final a2 = _account('a2');
  final accounts = [a1, a2];

  test('a recognised statement imports into its account', () {
    final match = OfxAccountMatched(_info('111'), a1);
    final target = importTargetFor(match, [match], const {}, accounts);
    expect(target?.account.id, 'a1');
    expect(target?.statement, '111');
  });

  test('an ambiguous statement waits for a choice, then takes it', () {
    final match = OfxAccountAmbiguous(_info('111'), accounts);
    expect(importTargetFor(match, [match], const {}, accounts), isNull);
    expect(
      importTargetFor(match, [match], const {'111': 'a2'}, accounts)?.account,
      a2,
    );
  });

  test('a file naming no account waits for a choice keyed by null', () {
    const match = OfxAccountUnreadable();
    expect(importTargetFor(match, [match], const {}, accounts), isNull);
    expect(
      importTargetFor(match, [match], const {null: 'a1'}, accounts)?.account,
      a1,
    );
  });

  test('an unknown account and an unreadable file never import', () {
    final unknown = OfxAccountUnmatched(_info('111'));
    const unreadable = OfxFileUnreadable();
    expect(importTargetFor(unknown, [unknown], const {}, accounts), isNull);
    expect(
      importTargetFor(unreadable, [unreadable], const {}, accounts),
      isNull,
    );
  });

  test('two statements landing in one account both block', () {
    final first = OfxAccountMatched(_info('111'), a1);
    final second = OfxAccountAmbiguous(_info('222'), accounts);
    final matches = [first, second];
    const chosen = {'222': 'a1'};

    expect(statementsSharingDestination(matches, chosen, accounts), {
      '111',
      '222',
    });
    expect(importTargetFor(first, matches, chosen, accounts), isNull);
    expect(importTargetFor(second, matches, chosen, accounts), isNull);

    // Pointing the second elsewhere frees both.
    const fixed = {'222': 'a2'};
    expect(statementsSharingDestination(matches, fixed, accounts), isEmpty);
    expect(importTargetFor(first, matches, fixed, accounts), isNotNull);
  });

  test('ready targets keep file order and skip unsettled statements', () {
    final first = OfxAccountMatched(_info('111'), a1);
    final waiting = OfxAccountAmbiguous(_info('222'), accounts);
    final unknown = OfxAccountUnmatched(_info('333'));
    final last = OfxAccountMatched(_info('444'), a2);
    final matches = [first, waiting, unknown, last];

    expect(
      readyImportTargets(
        matches,
        const {},
        accounts,
      ).map((t) => (t.statement, t.account.id)),
      [('111', 'a1'), ('444', 'a2')],
    );
  });

  test('ready targets leave out statements sharing a destination', () {
    final first = OfxAccountMatched(_info('111'), a1);
    final second = OfxAccountAmbiguous(_info('222'), accounts);
    expect(
      readyImportTargets([first, second], const {'222': 'a1'}, accounts),
      isEmpty,
    );
  });
}
