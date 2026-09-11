import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// Maps the backend's stable error `code` (see `CategoryNotFoundError` and
/// `core/errors.py`) to a localized message.
///
/// `CATEGORY_NOT_FOUND` is also what a forced edit of a system category comes
/// back as — system rows carry no `user_id`, so they are never user-owned — and
/// it is worth saying so in those words rather than as "not found": the row the
/// user is looking at plainly exists.
String localizeCategoryError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'CATEGORY_NOT_FOUND':
        return l10n.categoryErrorNotEditable;
      case 'VALIDATION_ERROR':
        return l10n.categoryErrorValidation;
    }
  }
  return l10n.categoryErrorGeneric;
}
