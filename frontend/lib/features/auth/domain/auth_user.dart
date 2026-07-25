import 'package:flutter/foundation.dart';

/// The authenticated user's profile. Locale and currency are account-wide
/// (Phase 1: one currency per user, chosen at registration — see
/// `PROJECT.md` §2 and the multi-currency skill).
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.locale,
    required this.currency,
  });

  final String id;
  final String email;
  final String displayName;
  final String locale;
  final String currency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.locale == locale &&
          other.currency == currency);

  @override
  int get hashCode => Object.hash(id, email, displayName, locale, currency);
}
