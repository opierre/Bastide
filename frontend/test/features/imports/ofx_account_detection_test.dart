import 'dart:convert';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/banks/data/banks_repository.dart';
import 'package:bastide/features/imports/application/imports_controller.dart';
import 'package:bastide/features/imports/application/ofx_account_detection.dart';
import 'package:bastide/features/imports/data/ofx_account_parser.dart';
import 'package:bastide/features/imports/domain/ofx_account_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// OFX 1.x SGML with unclosed leaf tags — the shape French banks actually emit.
const _sgml = '''
OFXHEADER:100
DATA:OFXSGML
VERSION:102

<OFX>
<SIGNONMSGSRSV1>
<SONRS>
<FI>
<ORG>BOURSORAMA BANQUE
<FID>1234
</FI>
</SONRS>
</SIGNONMSGSRSV1>
<BANKMSGSRSV1>
<STMTTRNRS>
<STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>40618
<ACCTID>0001234567
<ACCTTYPE>CHECKING
</BANKACCTFROM>
<BANKTRANLIST>
<STMTTRN>
<TRNAMT>-42.50
<DTPOSTED>20260105
<NAME>CARTE ACHAT
</STMTTRN>
</BANKTRANLIST>
<LEDGERBAL>
<BALAMT>1234.56
<DTASOF>20260131
</LEDGERBAL>
<AVAILBAL>
<BALAMT>999.00
<DTASOF>20260131
</AVAILBAL>
</STMTRS>
</STMTTRNRS>
</BANKMSGSRSV1>
</OFX>
''';

/// OFX 2.x XML, credit-card statement: no ACCTTYPE, the block is the type.
const _creditCardXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<OFX>
  <CREDITCARDMSGSRSV1>
    <CCSTMTTRNRS>
      <CCSTMTRS>
        <CURDEF>EUR</CURDEF>
        <CCACCTFROM>
          <ACCTID>5555444433339876</ACCTID>
        </CCACCTFROM>
      </CCSTMTRS>
    </CCSTMTTRNRS>
  </CREDITCARDMSGSRSV1>
</OFX>
''';

Account _account({
  String id = 'a1',
  String name = 'Compte courant',
  String institution = 'Boursorama',
  AccountType type = AccountType.checking,
  String? ofxAccountId,
}) => Account(
  id: id,
  name: name,
  type: type,
  institution: institution,
  ofxAccountId: ofxAccountId,
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

/// A statement whose signon block names no bank — all it says about its
/// institution is the 5-digit `code banque` of a Crédit Agricole regional bank.
const _bankCodeOnlySgml = '''
<OFX>
<BANKMSGSRSV1><STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>13306
<ACCTID>0009876543
<ACCTTYPE>CHECKING
</BANKACCTFROM>
</STMTRS></STMTTRNRS></BANKMSGSRSV1>
</OFX>
''';

/// Stands in for the backend's bank directory.
class _FakeBanksRepository extends BanksRepository {
  _FakeBanksRepository(this.names)
    : super(ApiClient(baseUrl: Uri.parse('http://127.0.0.1:1/api/v1')));

  final Map<String, String> names;
  final lookups = <String>[];

  @override
  Future<String?> nameForCode(String bankCode) async {
    lookups.add(bankCode);
    return names[bankCode.trim()];
  }
}

/// Runs [detect] against a container wired to [banks].
Future<List<OfxAccountMatch>> _detect(
  String ofx,
  List<Account> accounts,
  _FakeBanksRepository banks,
) async {
  final container = ProviderContainer(
    overrides: [banksRepositoryProvider.overrideWithValue(banks)],
  );
  addTearDown(container.dispose);

  return container
      .read(ofxAccountDetectionProvider.notifier)
      .detect(
        PickedImportFile(name: 'releve.ofx', bytes: utf8.encode(ofx)),
        accounts,
      );
}

/// The one statement of a single-account file, or `null` when it names none.
OfxAccountInfo? _single(List<int> bytes) =>
    parseOfxStatements(bytes).singleOrNull;

const _info = OfxAccountInfo(
  accountNumber: '0001234567',
  bankId: '40618',
  accountType: 'CHECKING',
  organization: 'BOURSORAMA BANQUE',
  currency: 'EUR',
);

void main() {
  group('parseOfxStatements', () {
    test('reads the account block out of unclosed SGML tags', () {
      final info = _single(utf8.encode(_sgml))!;

      expect(info.accountNumber, '0001234567');
      expect(info.bankId, '40618');
      expect(info.accountType, 'CHECKING');
      expect(info.organization, 'BOURSORAMA BANQUE');
      expect(info.currency, 'EUR');
      expect(info.maskedNumber, '••4567');
      // The declared closing balance, not the available one just after it.
      expect(info.ledgerBalanceMinor, 123456);
      // The day the balance holds at, so the account form can name it.
      expect(info.ledgerBalanceAsOf, DateTime(2026, 1, 31));
    });

    test('reads a balance whose DTASOF carries a time and a zone', () {
      final dated = _sgml.replaceFirst(
        '<DTASOF>20260131',
        '<DTASOF>20260131120000[+1:CET]',
      );

      expect(
        _single(utf8.encode(dated))!.ledgerBalanceAsOf,
        DateTime(2026, 1, 31),
      );
    });

    test('keeps a balance whose DTASOF is missing or unreadable', () {
      final undated = _sgml.replaceFirst(
        '<DTASOF>20260131',
        '<DTASOF>20260231',
      );

      final info = _single(utf8.encode(undated))!;
      expect(info.ledgerBalanceMinor, 123456);
      expect(info.ledgerBalanceAsOf, isNull);
    });

    test('reads no balance out of a statement that declares none', () {
      expect(_single(utf8.encode(_creditCardXml))!.ledgerBalanceMinor, isNull);
    });

    test(
      'reads a negative closing balance as an overdraft, not its absolute value',
      () {
        final overdrawn = _sgml.replaceFirst(
          '<BALAMT>1234.56',
          '<BALAMT>-42.05',
        );

        expect(_single(utf8.encode(overdrawn))!.ledgerBalanceMinor, -4205);
      },
    );

    test('reads closed XML tags and types a CCACCTFROM block as a card', () {
      final info = _single(utf8.encode(_creditCardXml))!;

      expect(info.accountNumber, '5555444433339876');
      expect(info.accountType, 'CREDITCARD');
      expect(info.isCardStatement, isTrue);
      // A French card statement is a deferred-debit card's until the user says
      // otherwise — the account form asks.
      expect(accountTypeFromOfx(info.accountType), AccountType.deferredCard);
      // No FI block: the label falls back to nothing rather than inventing one.
      expect(info.institutionLabel, isNull);
    });

    test('decodes Latin-1 bytes rather than mangling the bank name', () {
      final bytes = latin1.encode(
        _sgml.replaceAll('BOURSORAMA BANQUE', 'CAISSE D\'ÉPARGNE'),
      );

      expect(_single(bytes)!.organization, "CAISSE D'ÉPARGNE");
    });

    test('returns null for files that are not OFX or declare no account', () {
      expect(_single(utf8.encode('date;montant\n01/01/2026;-12,00')), isNull);
      expect(_single(utf8.encode('<OFX>\n<SONRS>\n</SONRS>\n</OFX>')), isNull);
      expect(_single(const [1, 2, 3]), isNull);
    });
  });

  group('matchOfxAccount', () {
    test('the bound bank account id settles it, whatever else looks close', () {
      final bound = _account(
        id: 'a2',
        name: 'Un tout autre nom',
        institution: 'Autre banque',
        type: AccountType.savings,
        ofxAccountId: '0001234567',
      );

      final match = matchOfxAccount(_info, [_account(), bound]);

      expect((match as OfxAccountMatched).account, bound);
    });

    test('matches on the account number even when the bank name differs', () {
      final numbered = _account(
        name: 'Courant ••4567',
        institution: 'BoursoBank',
      );

      final match = matchOfxAccount(_info, [_account(), numbered]);

      expect(match, isA<OfxAccountMatched>());
      expect((match as OfxAccountMatched).account, numbered);
    });

    test(
      'matches a bank name the user typed shorter than the file spells it',
      () {
        final match = matchOfxAccount(_info, [_account()]);

        expect((match as OfxAccountMatched).account.id, 'a1');
      },
    );

    test('uses the OFX account type to separate two accounts at one bank', () {
      final savings = _account(
        id: 'a2',
        name: 'Livret A',
        type: AccountType.savings,
      );

      final match = matchOfxAccount(_info, [_account(), savings]);

      expect((match as OfxAccountMatched).account.id, 'a1');
    });

    test('a card statement fits a card account of either kind', () {
      const card = OfxAccountInfo(
        accountNumber: '5555444433339876',
        accountType: 'CREDITCARD',
        organization: 'BOURSORAMA BANQUE',
      );

      for (final type in [AccountType.deferredCard, AccountType.credit]) {
        final cardAccount = _account(id: 'a2', name: 'Carte', type: type);

        final match = matchOfxAccount(card, [_account(), cardAccount]);

        expect((match as OfxAccountMatched).account.id, 'a2', reason: '$type');
      }
    });

    test('a credit line stays a credit account', () {
      expect(accountTypeFromOfx('CREDITLINE'), AccountType.credit);
    });

    test('refuses to guess between same-bank, same-type accounts', () {
      final second = _account(id: 'a2', name: 'Compte joint');

      final match = matchOfxAccount(_info, [_account(), second]);

      expect(match, isA<OfxAccountAmbiguous>());
      expect((match as OfxAccountAmbiguous).candidates, hasLength(2));
    });

    test('reports no match when nothing shares the bank', () {
      expect(
        matchOfxAccount(_info, [_account(institution: 'BNP Paribas')]),
        isA<OfxAccountUnmatched>(),
      );
      expect(matchOfxAccount(_info, const []), isA<OfxAccountUnmatched>());
    });

    test('names the bank from its code when the file names none itself', () {
      const info = OfxAccountInfo(accountNumber: '0009876543', bankId: '13306');

      expect(info.institutionLabel, '13306');
      expect(
        info.withBankName('Crédit Agricole').institutionLabel,
        'Crédit Agricole',
      );
      // The bank's own name for itself still wins over our lookup of it.
      expect(
        _info.withBankName('Boursorama').institutionLabel,
        'BOURSORAMA BANQUE',
      );
    });
  });

  group('OfxAccountDetection', () {
    test(
      'resolves the bank code so the proposed account is named, not numbered',
      () async {
        final banks = _FakeBanksRepository({'13306': 'Crédit Agricole'});

        final [match] = await _detect(_bankCodeOnlySgml, const [], banks);

        expect(banks.lookups, ['13306']);
        expect(match, isA<OfxAccountUnmatched>());
        expect(
          (match as OfxAccountUnmatched).info.institutionLabel,
          'Crédit Agricole',
        );
      },
    );

    test(
      'the resolved bank matches an account the user typed by name',
      () async {
        final banks = _FakeBanksRepository({'13306': 'Crédit Agricole'});
        final account = _account(
          name: 'Compte courant',
          institution: 'Crédit Agricole',
        );

        final [match] = await _detect(_bankCodeOnlySgml, [account], banks);

        expect((match as OfxAccountMatched).account, account);
      },
    );

    test('an unknown code leaves the file speaking for itself', () async {
      final banks = _FakeBanksRepository(const {});

      final [match] = await _detect(_bankCodeOnlySgml, const [], banks);

      expect((match as OfxAccountUnmatched).info.institutionLabel, '13306');
    });

    test(
      'a file with no readable account block is a question, not a silence',
      () async {
        // With no destination selector left, "we could not read this" has to be a
        // verdict the panel can act on rather than an absent one it ignores.
        final banks = _FakeBanksRepository(const {});
        final container = ProviderContainer(
          overrides: [banksRepositoryProvider.overrideWithValue(banks)],
        );
        addTearDown(container.dispose);

        final [match] = await container
            .read(ofxAccountDetectionProvider.notifier)
            .detect(
              const PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]),
              [_account()],
            );

        expect(match, isA<OfxAccountUnreadable>());
        expect(
          container.read(ofxAccountDetectionProvider)!.single,
          isA<OfxAccountUnreadable>(),
        );
      },
    );

    test('a file that names its bank is not looked up at all', () async {
      final banks = _FakeBanksRepository({'40618': 'Boursorama'});

      await _detect(_sgml, const [], banks);

      expect(banks.lookups, isEmpty);
    });
  });

  group('several statements in one file', () {
    test('each statement is read on its own, balance included', () {
      final statements = parseOfxStatements(utf8.encode(_multiSgml));

      expect(statements.map((s) => s.accountNumber), [
        '0001234567',
        '0007654321',
      ]);
      expect(statements.map((s) => s.accountType), ['CHECKING', 'SAVINGS']);
      expect(statements.map((s) => s.ledgerBalanceMinor), [123456, 520000]);
      // The signon block names the bank once, for every statement.
      expect(
        statements.map((s) => s.organization),
        everyElement('BOURSORAMA BANQUE'),
      );
    });

    test('a bound account is claimed before any guess is made', () {
      // The savings statement alone would match the checking account by bank;
      // the checking statement's binding takes it off the table first.
      final checking = _account(ofxAccountId: '0001234567');
      final statements = parseOfxStatements(utf8.encode(_multiSgml));

      final matches = matchOfxStatements(statements, [checking]);

      expect((matches[0] as OfxAccountMatched).account, checking);
      expect(matches[1], isA<OfxAccountUnmatched>());
    });

    test('a card statement borrows the bank code of its bank statements', () {
      final statements = parseOfxStatements(utf8.encode(_bankAndCardSgml));

      expect(statements.map((s) => s.accountType), ['CHECKING', 'CREDITCARD']);
      expect(statements.map((s) => s.bankId), everyElement('13306'));
    });

    test('a card statement on its own still names no bank', () {
      expect(_single(utf8.encode(_creditCardXml))!.bankId, isNull);
    });

    test('bank statements that disagree lend the card no code', () {
      final ofx = _bankAndCardSgml.replaceFirst(
        '</STMTRS></STMTTRNRS></BANKMSGSRSV1>',
        '</STMTRS></STMTTRNRS><STMTTRNRS><STMTRS>\n<BANKACCTFROM>\n'
            '<BANKID>30004\n<ACCTID>0001111111\n<ACCTTYPE>SAVINGS\n'
            '</BANKACCTFROM>\n</STMTRS></STMTTRNRS></BANKMSGSRSV1>',
      );

      final statements = parseOfxStatements(utf8.encode(ofx));

      expect(statements.map((s) => s.bankId), ['13306', '30004', null]);
    });

    test(
      'the borrowed code names the card bank when the file does not',
      () async {
        final banks = _FakeBanksRepository({'13306': 'Crédit Agricole'});

        final matches = await _detect(_bankAndCardSgml, const [], banks);

        expect(
          matches.map((m) => (m as OfxAccountUnmatched).info.institutionLabel),
          everyElement('Crédit Agricole'),
        );
      },
    );

    test('two statements guessing the same account are both asked', () {
      final only = _account(type: AccountType.other);
      final statements = parseOfxStatements(utf8.encode(_multiSgml));

      final matches = matchOfxStatements(statements, [only]);

      expect(matches, everyElement(isA<OfxAccountAmbiguous>()));
      expect((matches[0] as OfxAccountAmbiguous).candidates, [only]);
    });
  });
}

/// Two statements of one Boursorama customer in a single file.
const _multiSgml = '''
<OFX>
<SIGNONMSGSRSV1><SONRS><FI><ORG>BOURSORAMA BANQUE
</FI></SONRS></SIGNONMSGSRSV1>
<BANKMSGSRSV1>
<STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>40618
<ACCTID>0001234567
<ACCTTYPE>CHECKING
</BANKACCTFROM>
<LEDGERBAL>
<BALAMT>1234.56
<DTASOF>20260131
</LEDGERBAL>
</STMTRS></STMTTRNRS>
<STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>40618
<ACCTID>0007654321
<ACCTTYPE>SAVINGS
</BANKACCTFROM>
<LEDGERBAL>
<BALAMT>5200.00
<DTASOF>20260131
</LEDGERBAL>
</STMTRS></STMTTRNRS>
</BANKMSGSRSV1>
</OFX>
''';

/// A Crédit Agricole export holding the current account and the deferred-debit
/// card drawn on it. Neither the signon block nor the card names the bank: only
/// the current account's `BANKID` does.
const _bankAndCardSgml = '''
<OFX>
<BANKMSGSRSV1><STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>13306
<ACCTID>0009876543
<ACCTTYPE>CHECKING
</BANKACCTFROM>
</STMTRS></STMTTRNRS></BANKMSGSRSV1>
<CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS>
<CURDEF>EUR
<CCACCTFROM>
<ACCTID>4970XXXXXXXX1234
</CCACCTFROM>
</CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>
</OFX>
''';
