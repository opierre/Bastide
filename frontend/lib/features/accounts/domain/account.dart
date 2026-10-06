import 'package:flutter/foundation.dart';

/// Mirrors the backend's `AccountType` literal (`schemas.py`). Declaration
/// order is the order the type selector offers them in.
enum AccountType {
  checking('checking'),
  savings('savings'),
  credit('credit'),

  /// The holding account a deferred-debit card gets: French banks post card
  /// purchases to it through the month and settle the total against the current
  /// account on one date. Its own balance is what the user watches, so it is a
  /// type of its own rather than a flag on [credit].
  deferredCard('deferred_card'),
  cash('cash'),
  other('other');

  const AccountType(this.wireValue);

  /// The literal the backend uses. Carried explicitly rather than derived from
  /// `.name`, which can't spell a snake_case wire value.
  final String wireValue;

  static AccountType fromWire(String value) => AccountType.values.firstWhere(
    (type) => type.wireValue == value,
    orElse: () => AccountType.other,
  );
}

/// Values proposed for an account the user hasn't created yet — read out of a
/// statement file rather than typed. Every field is optional: the form falls
/// back to its own defaults for whatever the source couldn't tell us.
@immutable
class AccountPrefill {
  const AccountPrefill({
    this.name,
    this.institution,
    this.type,
    this.ofxAccountId,
    this.balanceMinor,
    this.balanceAsOf,
    this.currency,
  });

  final String? name;
  final String? institution;
  final AccountType? type;

  /// The currency the source declares its figures are in — an OFX statement's
  /// `CURDEF`. Preferred over the profile currency and sent on to the backend,
  /// because the file is stating a fact about the account, where the profile is
  /// only our default guess at it. `null` when the source declares none, and
  /// the account takes the user's currency as every hand-made account does.
  final String? currency;

  /// The balance the source declares the account holds — an OFX statement's
  /// `LEDGERBAL`. Fills the create form's balance field, which means exactly
  /// that before any transaction lands. `null` when the source declares none,
  /// and the user types it as before.
  final int? balanceMinor;

  /// The date [balanceMinor] holds at (`DTASOF`), when the source dates it.
  /// The form names the field by it, because a statement's closing balance is
  /// only "current" on the day the statement was cut.
  final DateTime? balanceAsOf;

  /// Carried through creation but never shown as a field: it is the bank's
  /// identifier, not something the user has an opinion about.
  final String? ofxAccountId;
}

/// An account as returned by the API, including its derived current balance.
/// Currency is set by the backend from the user's currency (one
/// currency per user) and is never picked per account — see the
/// multi-currency skill.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.institution,
    required this.currency,
    this.ofxAccountId,
    required this.openingBalanceMinor,
    required this.balanceMinor,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String institution;
  final String currency;

  /// The bank's own id for this account (OFX `ACCTID`), when we know it —
  /// what makes a statement identify its account exactly rather than by name.
  final String? ofxAccountId;
  final int openingBalanceMinor;
  final int balanceMinor;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == id &&
          other.name == name &&
          other.type == type &&
          other.institution == institution &&
          other.currency == currency &&
          other.ofxAccountId == ofxAccountId &&
          other.openingBalanceMinor == openingBalanceMinor &&
          other.balanceMinor == balanceMinor &&
          other.archived == archived &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    institution,
    currency,
    ofxAccountId,
    openingBalanceMinor,
    balanceMinor,
    archived,
    createdAt,
    updatedAt,
  );
}
