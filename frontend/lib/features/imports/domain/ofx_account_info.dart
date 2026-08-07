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
    this.bankName,
    this.accountType,
    this.organization,
    this.currency,
    this.ledgerBalanceMinor,
  });

  /// `ACCTID` — the bank's account number. The one field worth having: it is
  /// what makes two statements from the same bank distinguishable.
  final String accountNumber;

  /// `BANKID` — the bank code. In France its leading five digits are the
  /// `code banque` from the RIB (13306 is a Crédit Agricole regional bank).
  final String? bankId;

  /// The bank [bankId] was resolved to, when the backend's directory knows it.
  /// Not read from the file: it is what turns `13306` into `Crédit Agricole`
  /// for a statement whose signon block names no bank.
  final String? bankName;

  /// `ACCTTYPE` as written in the file (`CHECKING`, `SAVINGS`, `CREDITLINE`…),
  /// or `CREDITCARD` when the statement is a `CCACCTFROM` block.
  final String? accountType;

  /// `ORG` from the signon block — the bank's own name for itself.
  final String? organization;

  /// `CURDEF` — the statement's currency.
  final String? currency;

  /// `LEDGERBAL/BALAMT` in minor units — the closing balance the statement
  /// declares for its account, or `null` when it declares none (not every
  /// exporter emits one). Not part of matching: it says nothing about *which*
  /// account this is. It is here for the account the statement proposes, whose
  /// balance would otherwise have to be typed from memory.
  final int? ledgerBalanceMinor;

  /// The best available human label for the bank: the name it declares for
  /// itself, else the one its bank code resolves to, else the bare code, else
  /// nothing. A declared name wins because it is the bank's own answer, where
  /// the directory is only our lookup of it.
  String? get institutionLabel {
    for (final candidate in [organization, bankName, bankId]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// This account block with the bank its code was resolved to attached.
  OfxAccountInfo withBankName(String? name) => OfxAccountInfo(
    accountNumber: accountNumber,
    bankId: bankId,
    bankName: name,
    accountType: accountType,
    organization: organization,
    currency: currency,
    ledgerBalanceMinor: ledgerBalanceMinor,
  );

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
          other.bankName == bankName &&
          other.accountType == accountType &&
          other.organization == organization &&
          other.currency == currency &&
          other.ledgerBalanceMinor == ledgerBalanceMinor);

  @override
  int get hashCode => Object.hash(
    accountNumber,
    bankId,
    bankName,
    accountType,
    organization,
    currency,
    ledgerBalanceMinor,
  );
}
