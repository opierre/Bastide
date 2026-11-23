import 'package:flutter/foundation.dart';

import 'avatar_choice.dart';
import 'text_size_preference.dart';
import 'theme_preference.dart';

/// The authenticated user's profile. Locale and currency are account-wide
/// (one currency per user, chosen at registration — see
/// the multi-currency skill).
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.locale,
    required this.currency,
    this.avatar = const MonogramChoice(),
    this.theme = ThemePreference.dark,
    this.textSize = TextSizePreference.normal,
  });

  final String id;
  final String email;
  final String displayName;
  final String locale;
  final String currency;
  final AvatarChoice avatar;
  final ThemePreference theme;
  final TextSizePreference textSize;

  /// This user with [theme] in place of their current one.
  AuthUser withTheme(ThemePreference theme) => AuthUser(
    id: id,
    email: email,
    displayName: displayName,
    locale: locale,
    currency: currency,
    avatar: avatar,
    theme: theme,
    textSize: textSize,
  );

  /// This user with [textSize] in place of their current one.
  AuthUser withTextSize(TextSizePreference textSize) => AuthUser(
    id: id,
    email: email,
    displayName: displayName,
    locale: locale,
    currency: currency,
    avatar: avatar,
    theme: theme,
    textSize: textSize,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.locale == locale &&
          other.currency == currency &&
          other.avatar == avatar &&
          other.theme == theme &&
          other.textSize == textSize);

  @override
  int get hashCode => Object.hash(
    id,
    email,
    displayName,
    locale,
    currency,
    avatar,
    theme,
    textSize,
  );
}
