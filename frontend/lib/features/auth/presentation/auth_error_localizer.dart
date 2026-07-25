import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// Maps the backend's stable error `code` (see `core/errors.py`) to a
/// localized message. New codes need a matching ARB key — see the
/// i18n-l10n skill.
String localizeAuthError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'INVALID_CREDENTIALS':
        return l10n.authErrorInvalidCredentials;
      case 'EMAIL_TAKEN':
        return l10n.authErrorEmailTaken;
      case 'VALIDATION_ERROR':
        return l10n.authErrorValidation;
    }
  }
  return l10n.authErrorGeneric;
}
