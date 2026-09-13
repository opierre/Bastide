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
// `AVAILBAL` carries a different figure (funds available, including holds), so
// the tag is matched exactly rather than on a `BAL` suffix — same rule as the
// backend parser, which derives the opening balance from this very value.
final _ledgerBalRe = RegExp(
  r'<LEDGERBAL>(.*?)(?:</LEDGERBAL>|$)',
  caseSensitive: false,
  dotAll: true,
);

/// Pulls a leaf value, stopping at the next tag or end of line so it works
/// whether or not the leaf tag is closed.
String? _tag(String block, String tag) {
  final match = RegExp(
    '<$tag>\\s*([^<\r\n]*)',
    caseSensitive: false,
  ).firstMatch(block);
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

/// `BALAMT` in minor units, or `null` when it can't be read as a number.
///
/// Deliberately as strict as the backend's `_parse_amount_minor` (a plain
/// decimal, `.` separator): reading a figure here that the backend would reject
/// would show the user a balance the first import then fails to reproduce.
int? _parseAmountMinor(String? value) {
  final parsed = value == null ? null : double.tryParse(value.trim());
  return parsed == null ? null : (parsed * 100).round();
}

/// An OFX timestamp (`YYYYMMDD` plus an optional time and zone we ignore), or
/// `null` when it isn't one. Only the date half is read, and only as a label:
/// the balance itself is what the import reconciles against.
DateTime? _parseDate(String? value) {
  final digits = value?.trim() ?? '';
  if (digits.length < 8) return null;
  final year = int.tryParse(digits.substring(0, 4));
  final month = int.tryParse(digits.substring(4, 6));
  final day = int.tryParse(digits.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final parsed = DateTime(year, month, day);
  // DateTime rolls an out-of-range day into the next month rather than
  // rejecting it, so 20260231 would silently become 3 March.
  return parsed.month == month && parsed.day == day ? parsed : null;
}

/// The closing balance the statement declares (`LEDGERBAL`), with the date it
/// holds at (`DTASOF`).
///
/// The one figure in the file saying where the account actually stands, as
/// opposed to how it moved — which is what lets the account form propose a real
/// balance instead of asking for one nobody can look up. A file holding several
/// statements is read for the first, matching the account block we route on.
///
/// `DTASOF` is mandatory in the spec but not every exporter emits it, so the
/// date is optional and the balance stands on its own without it — the same
/// tolerance the backend's `parse_ledger_balance` applies.
({int amountMinor, DateTime? asOf})? _parseLedgerBalance(String text) {
  final match = _ledgerBalRe.firstMatch(text);
  if (match == null) return null;
  final block = match.group(1)!;
  final amountMinor = _parseAmountMinor(_tag(block, 'BALAMT'));
  if (amountMinor == null) return null;
  return (amountMinor: amountMinor, asOf: _parseDate(_tag(block, 'DTASOF')));
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

  final ledgerBalance = _parseLedgerBalance(text);

  return OfxAccountInfo(
    accountNumber: accountNumber,
    bankId: _tag(block, 'BANKID'),
    accountType: isCreditCard ? 'CREDITCARD' : _tag(block, 'ACCTTYPE'),
    organization: _tag(text, 'ORG'),
    currency: _tag(text, 'CURDEF'),
    ledgerBalanceMinor: ledgerBalance?.amountMinor,
    ledgerBalanceAsOf: ledgerBalance?.asOf,
  );
}
