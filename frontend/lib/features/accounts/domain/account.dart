import 'package:flutter/foundation.dart';

/// Mirrors the backend's `AccountType` literal (`schemas.py`). Enum member
/// names match the wire values exactly, so `.name` round-trips both ways.
enum AccountType {
  checking,
  savings,
  credit,
  cash,
  other;

  static AccountType fromWire(String value) =>
      AccountType.values.firstWhere((type) => type.name == value, orElse: () => AccountType.other);

  String get wireValue => name;
}

/// An account as returned by the API, including its derived current balance.
/// Currency is set by the backend from the user's currency (Phase 1: one
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
    openingBalanceMinor,
    balanceMinor,
    archived,
    createdAt,
    updatedAt,
  );
}
