import '../../../core/l10n/category_display.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../domain/rule.dart';

/// The localized name of the transaction field a rule reads.
String ruleFieldLabel(AppLocalizations l10n, RuleMatchField field) => switch (field) {
  RuleMatchField.descriptionClean => l10n.ruleFieldDescription,
  RuleMatchField.merchant => l10n.ruleFieldMerchant,
  RuleMatchField.amount => l10n.ruleFieldAmount,
};

/// The localized condition badge — « contient », « égal à », « regex »,
/// « plage » (`docs/design/08`).
String ruleConditionLabel(AppLocalizations l10n, RuleMatchType type) => switch (type) {
  RuleMatchType.contains => l10n.ruleConditionContains,
  RuleMatchType.equals => l10n.ruleConditionEquals,
  RuleMatchType.regex => l10n.ruleConditionRegex,
  RuleMatchType.range => l10n.ruleConditionRange,
};

/// What to type in the pattern field, which differs sharply per condition: a
/// `range` takes `min:max` in minor units (`engine.py`), and a user given the
/// generic "type what to look for" would enter « 50 € » and match nothing.
String rulePatternHelper(AppLocalizations l10n, RuleMatchType type) => switch (type) {
  RuleMatchType.regex => l10n.rulePatternHelperRegex,
  RuleMatchType.range => l10n.rulePatternHelperRange,
  _ => l10n.rulePatternHelperText,
};

String rulePatternHint(AppLocalizations l10n, RuleMatchType type) => switch (type) {
  RuleMatchType.regex => l10n.rulePatternHintRegex,
  RuleMatchType.range => l10n.rulePatternHintRange,
  _ => l10n.rulePatternHintText,
};

/// « Alimentation › Courses » — the parent is what disambiguates a subcategory
/// whose own name (« Autres », « Assurance ») repeats across several groups.
String categoryPath(
  AppLocalizations l10n,
  AppCategory category,
  List<AppCategory> catalog,
) {
  final name = localizedCategoryName(l10n, category.name);
  final parentId = category.parentId;
  if (parentId == null) return name;
  for (final candidate in catalog) {
    if (candidate.id == parentId) {
      return '${localizedCategoryName(l10n, candidate.name)} › $name';
    }
  }
  return name;
}
