import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/features/auth/presentation/auth_error_localizer.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tooShort = ApiFailure(
    code: 'PASSWORD_TOO_SHORT',
    message: 'Password must be at least 12 characters.',
    details: {'min_length': 12},
  );

  test('PASSWORD_TOO_SHORT is localized in French', () {
    final l10n = lookupAppLocalizations(const Locale('fr'));

    expect(
      localizeAuthError(l10n, tooShort),
      'Le mot de passe doit contenir au moins 12 caractères.',
    );
  });

  test('PASSWORD_TOO_SHORT is localized in English', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(
      localizeAuthError(l10n, tooShort),
      'The password must be at least 12 characters long.',
    );
  });
}
