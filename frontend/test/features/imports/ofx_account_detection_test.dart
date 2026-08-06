import 'dart:convert';

import 'package:finstride/features/accounts/domain/account.dart';
import 'package:finstride/features/imports/application/ofx_account_detection.dart';
import 'package:finstride/features/imports/data/ofx_account_parser.dart';
import 'package:finstride/features/imports/domain/ofx_account_info.dart';
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
}) => Account(
  id: id,
  name: name,
  type: type,
  institution: institution,
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

const _info = OfxAccountInfo(
  accountNumber: '0001234567',
  bankId: '40618',
  accountType: 'CHECKING',
  organization: 'BOURSORAMA BANQUE',
  currency: 'EUR',
);

void main() {
  group('parseOfxAccountInfo', () {
    test('reads the account block out of unclosed SGML tags', () {
      final info = parseOfxAccountInfo(utf8.encode(_sgml))!;

      expect(info.accountNumber, '0001234567');
      expect(info.bankId, '40618');
      expect(info.accountType, 'CHECKING');
      expect(info.organization, 'BOURSORAMA BANQUE');
      expect(info.currency, 'EUR');
      expect(info.maskedNumber, '••4567');
    });

    test('reads closed XML tags and types a CCACCTFROM block as a card', () {
      final info = parseOfxAccountInfo(utf8.encode(_creditCardXml))!;

      expect(info.accountNumber, '5555444433339876');
      expect(info.accountType, 'CREDITCARD');
      expect(accountTypeFromOfx(info.accountType), AccountType.credit);
      // No FI block: the label falls back to nothing rather than inventing one.
      expect(info.institutionLabel, isNull);
    });

    test('decodes Latin-1 bytes rather than mangling the bank name', () {
      final bytes = latin1.encode(
        _sgml.replaceAll('BOURSORAMA BANQUE', 'CAISSE D\'ÉPARGNE'),
      );

      expect(parseOfxAccountInfo(bytes)!.organization, "CAISSE D'ÉPARGNE");
    });

    test('returns null for files that are not OFX or declare no account', () {
      expect(parseOfxAccountInfo(utf8.encode('date;montant\n01/01/2026;-12,00')), isNull);
      expect(parseOfxAccountInfo(utf8.encode('<OFX>\n<SONRS>\n</SONRS>\n</OFX>')), isNull);
      expect(parseOfxAccountInfo(const [1, 2, 3]), isNull);
    });
  });

  group('matchOfxAccount', () {
    test('matches on the account number even when the bank name differs', () {
      final numbered = _account(name: 'Courant ••4567', institution: 'BoursoBank');

      final match = matchOfxAccount(_info, [_account(), numbered]);

      expect(match, isA<OfxAccountMatched>());
      expect((match as OfxAccountMatched).account, numbered);
    });

    test('matches a bank name the user typed shorter than the file spells it', () {
      final match = matchOfxAccount(_info, [_account()]);

      expect((match as OfxAccountMatched).account.id, 'a1');
    });

    test('uses the OFX account type to separate two accounts at one bank', () {
      final savings = _account(id: 'a2', name: 'Livret A', type: AccountType.savings);

      final match = matchOfxAccount(_info, [_account(), savings]);

      expect((match as OfxAccountMatched).account.id, 'a1');
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
  });
}
