import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// True when the failure is an uncompilable `regex` pattern.
///
/// Worth its own predicate because it decides *where* the message goes: this
/// one belongs on the pattern field, and every other failure is a preview or a
/// save that couldn't run. "No matches" and "not a valid pattern" are different
/// answers, and rendering the second as the first is how a user ends up
/// deleting a rule that was one character from working.
bool isRulePatternInvalid(Object? error) =>
    error is ApiFailure && error.code == 'RULE_PATTERN_INVALID';

/// Maps the backend's stable error `code` to a localized message.
String localizeRuleError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'RULE_PATTERN_INVALID':
        return l10n.ruleErrorPatternInvalid;
      case 'RULE_NOT_FOUND':
        return l10n.ruleErrorNotFound;
      // A rule's category is a *field* of the rule, so the backend answers
      // `CATEGORY_INVALID` (422) rather than the `CATEGORY_NOT_FOUND` (404) it
      // uses when a category is the addressed resource. The message is the
      // same either way; only the code the rules endpoints emit changed.
      case 'CATEGORY_INVALID':
        return l10n.ruleErrorCategoryNotFound;
      case 'VALIDATION_ERROR':
        return l10n.ruleErrorValidation;
    }
  }
  return l10n.ruleErrorGeneric;
}
