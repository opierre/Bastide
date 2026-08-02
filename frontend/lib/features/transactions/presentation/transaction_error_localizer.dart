import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// Maps the backend's stable error `code` (`TransactionNotFoundError`,
/// `RuleNotFoundError` — see `core/errors.py`) to a localized message. New
/// codes need a matching ARB key — see the i18n-l10n skill.
String localizeTransactionError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'TRANSACTION_NOT_FOUND':
        return l10n.transactionErrorNotFound;
      case 'VALIDATION_ERROR':
        return l10n.transactionErrorValidation;
    }
  }
  return l10n.transactionErrorGeneric;
}
