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

/// The parser's own detail line, when the failure carries one.
///
/// Returned separately from [localizeImportError] because it is untranslated
/// backend data — it names the column or row that could not be read, which the
/// localized headline deliberately doesn't guess at. Shown in a quieter tone
/// beneath the message, never on its own.
String? importErrorDetail(Object? error) {
  if (error is! ApiFailure) return null;
  final message = error.message.trim();
  return message.isEmpty ? null : message;
}
