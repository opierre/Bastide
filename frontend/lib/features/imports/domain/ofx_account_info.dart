import 'package:flutter/foundation.dart';

/// The account a statement declares it belongs to, as read from the OFX/QFX
/// header — before we know whether it corresponds to an account the user has.
///
/// Values stay exactly as the file spells them (`ACCTTYPE` is the raw OFX
/// literal, not our [AccountType]): translating them into our own vocabulary is
/// the matcher's job, not the file's.
@immutable
class OfxAccountInfo {
  const OfxAccountInfo({
    required this.accountNumber,
    this.bankId,
    this.accountType,
    this.organization,
    this.currency,
  });

  /// `ACCTID` — the bank's account number. The one field worth having: it is
  /// what makes two statements from the same bank distinguishable.
  final String accountNumber;

  /// `BANKID` — routing/branch code. Used as a fallback institution label when
  /// the file carries no `ORG`.
  final String? bankId;

  /// `ACCTTYPE` as written in the file (`CHECKING`, `SAVINGS`, `CREDITLINE`…),
  /// or `CREDITCARD` when the statement is a `CCACCTFROM` block.
  final String? accountType;

  /// `ORG` from the signon block — the bank's own name for itself.
  final String? organization;

  /// `CURDEF` — the statement's currency.
  final String? currency;

  /// The best available human label for the bank: its declared name, else its
  /// routing code, else nothing.
  String? get institutionLabel {
    final org = organization?.trim();
    if (org != null && org.isNotEmpty) return org;
    final id = bankId?.trim();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  /// The account number reduced to what is safe and useful to show: the last
  /// four characters behind a mask, e.g. `••4567`.
  String get maskedNumber {
    final trimmed = accountNumber.trim();
    if (trimmed.length <= 4) return trimmed;
    return '••${trimmed.substring(trimmed.length - 4)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfxAccountInfo &&
          other.accountNumber == accountNumber &&
          other.bankId == bankId &&
          other.accountType == accountType &&
          other.organization == organization &&
          other.currency == currency);

  @override
  int get hashCode =>
      Object.hash(accountNumber, bankId, accountType, organization, currency);
}
