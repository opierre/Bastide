import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// Maps the backend's stable error `code` (see `AccountNotFoundError` and
/// `core/errors.py`) to a localized message. New codes need a matching ARB
/// key — see the i18n-l10n skill.
String localizeAccountError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'ACCOUNT_NOT_FOUND':
        return l10n.accountErrorNotFound;
      case 'VALIDATION_ERROR':
        return l10n.accountErrorValidation;
    }
  }
  return l10n.accountErrorGeneric;
}
