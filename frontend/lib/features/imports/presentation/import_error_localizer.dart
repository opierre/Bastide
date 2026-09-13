import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// Maps the backend's stable error `code` (see `features/imports/service.py`)
/// to a localized message. New codes need a matching ARB key — see the
/// i18n-l10n skill.
String localizeImportError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'ACCOUNT_NOT_FOUND':
        return l10n.importErrorAccountNotFound;
      case 'IMPORT_BATCH_NOT_FOUND':
        return l10n.importErrorBatchNotFound;
    }
  }
  return l10n.importErrorGeneric;
}
