import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// Maps the recurring feature's stable error `code`s (see
/// `backend/app/features/recurring/service.py`) to a localized message.
///
/// `RECURRING_INVALID_TRANSITION` is the one the panel is most likely to meet
/// even though it never offers an illegal transition: the kebab is built from a
/// row that may be a few seconds old, and a series confirmed in another window
/// is enough to make a legal-looking click illegal by the time it lands.
String localizeRecurringError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'RECURRING_INVALID_TRANSITION':
        return l10n.subscriptionErrorInvalidTransition;
      case 'RECURRING_SERIES_EXISTS':
        return l10n.subscriptionErrorExists;
      case 'RECURRING_SERIES_NOT_FOUND':
        return l10n.subscriptionErrorNotFound;
      case 'ACCOUNT_NOT_FOUND':
        return l10n.subscriptionErrorAccountNotFound;
      case 'VALIDATION_ERROR':
        return l10n.subscriptionErrorValidation;
    }
  }
  return l10n.subscriptionErrorGeneric;
}
