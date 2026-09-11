import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../domain/rule.dart';
import 'rules_controller.dart';

/// The category the rules view is narrowed to, or `null` for every rule.
///
/// Set by a category card's footer (« 4 règles automatiques »), which opens the
/// rules view on that category's rules (`docs/design/08`). A top-level
/// category's filter takes in its subcategories too, so the list shows exactly
/// the rules the card counted.
class RulesCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? categoryId) => state = categoryId;
}

final rulesCategoryFilterProvider = NotifierProvider<RulesCategoryFilter, String?>(
  RulesCategoryFilter.new,
);

/// The id a rule counts toward on the categories panel: its target's parent
/// when the target is a subcategory, otherwise the target itself.
@visibleForTesting
String rootCategoryIdOf(String categoryId, Map<String, AppCategory> byId) =>
    byId[categoryId]?.parentId ?? categoryId;

/// How many rules target each top-level category, subcategories folded in and
/// disabled rules included — a disabled rule is still one the user wrote for
/// that category, and the filtered list it links to shows it.
///
/// `null` while either list is loading or has failed: the card footer then
/// states nothing rather than « Aucune règle », which would be a false claim.
final ruleCountsByCategoryProvider = Provider<Map<String, int>?>((ref) {
  final rules = ref.watch(rulesControllerProvider).value;
  final categories = ref.watch(categoriesControllerProvider).value;
  if (rules == null || categories == null) return null;
  return countRulesByRootCategory(rules, categories);
});

@visibleForTesting
Map<String, int> countRulesByRootCategory(
  List<Rule> rules,
  List<AppCategory> categories,
) {
  final byId = {for (final category in categories) category.id: category};
  final counts = <String, int>{};
  for (final rule in rules) {
    final root = rootCategoryIdOf(rule.categoryId, byId);
    counts[root] = (counts[root] ?? 0) + 1;
  }
  return counts;
}

/// The rules the view lists: all of them, or those under the filtered
/// category, in priority order either way.
final visibleRulesProvider = Provider<AsyncValue<List<Rule>>>((ref) {
  final filter = ref.watch(rulesCategoryFilterProvider);
  final rules = ref.watch(rulesControllerProvider);
  if (filter == null) return rules;

  final categories = ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
  final byId = {for (final category in categories) category.id: category};
  return rules.whenData(
    (list) => [
      for (final rule in list)
        if (rootCategoryIdOf(rule.categoryId, byId) == filter) rule,
    ],
  );
});
