import 'dart:convert';

import '../domain/ofx_account_info.dart';

/// Reads the account block out of an OFX/QFX file, client-side.
///
/// This is a header reader, not a second transaction parser: the backend stays
/// the only thing that turns a statement into transactions. All we want here is
/// the answer to "which account is this statement for", early enough to point
/// the import at the right account — or to offer to create it.
///
/// Deliberately regex-based rather than XML-based, for the same reason as the
/// backend parser (`parsers/ofx.py`): French banks emit OFX 1.x SGML with
/// unclosed leaf tags and Latin-1 bytes, which no XML parser will accept.

final _ofxRootRe = RegExp(r'<OFX[>\s]', caseSensitive: false);
final _acctFromRe = RegExp(
  r'<(BANK|CC)ACCTFROM>(.*?)(?:</\1ACCTFROM>|$)',
  caseSensitive: false,
  dotAll: true,
);

/// Pulls a leaf value, stopping at the next tag or end of line so it works
/// whether or not the leaf tag is closed.
String? _tag(String block, String tag) {
  final match = RegExp('<$tag>\\s*([^<\r\n]*)', caseSensitive: false).firstMatch(block);
  if (match == null) return null;
  final value = match.group(1)!.trim();
  return value.isEmpty ? null : value;
}

/// Decodes statement bytes, falling back to Latin-1 the way the backend does —
/// a French export is as likely to be Windows-1252 as UTF-8.
String decodeOfx(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

/// The account block of [bytes], or `null` when the file isn't OFX or declares
/// no account number — in which case the panel simply behaves as it did before.
OfxAccountInfo? parseOfxAccountInfo(List<int> bytes) {
  final text = decodeOfx(bytes);
  if (_ofxRootRe.firstMatch(text) == null) return null;

  final acctFrom = _acctFromRe.firstMatch(text);
  if (acctFrom == null) return null;
  final block = acctFrom.group(2)!;
  final accountNumber = _tag(block, 'ACCTID');
  if (accountNumber == null) return null;

  // A credit-card statement has no ACCTTYPE — the block it lives in is the type.
  final isCreditCard = acctFrom.group(1)!.toUpperCase() == 'CC';

  return OfxAccountInfo(
    accountNumber: accountNumber,
    bankId: _tag(block, 'BANKID'),
    accountType: isCreditCard ? 'CREDITCARD' : _tag(block, 'ACCTTYPE'),
    organization: _tag(text, 'ORG'),
    currency: _tag(text, 'CURDEF'),
  );
}
