import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../domain/rule.dart';
import 'rules_controller.dart';

/// The category the rules pane is narrowed to, or `null` for every rule.
///
/// It is the selection of the panel's category tree: « Toutes les règles » is
/// `null`, a top-level category its id (`docs/design/08`). A top-level
/// category's filter takes in its subcategories too, so the pane shows exactly
/// the rules the tree counted.
class RulesCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? categoryId) => state = categoryId;
}

final rulesCategoryFilterProvider =
    NotifierProvider<RulesCategoryFilter, String?>(RulesCategoryFilter.new);

/// The id a rule counts toward on the categories panel: its target's parent
/// when the target is a subcategory, otherwise the target itself.
@visibleForTesting
String rootCategoryIdOf(String categoryId, Map<String, AppCategory> byId) =>
    byId[categoryId]?.parentId ?? categoryId;

/// How many rules target each top-level category, subcategories folded in and
/// disabled rules included — a disabled rule is still one the user wrote for
/// that category, and the filtered list it links to shows it.
///
/// `null` while either list is loading or has failed: the tree then states
/// nothing rather than « aucune règle », which would be a false claim.
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

  final categories =
      ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
  final byId = {for (final category in categories) category.id: category};
  return rules.whenData(
    (list) => [
      for (final rule in list)
        if (rootCategoryIdOf(rule.categoryId, byId) == filter) rule,
    ],
  );
});

/// Each rule's place in the evaluation order, from 1, keyed by rule id.
///
/// Taken from the whole list, so a rule keeps its number while the pane is
/// filtered: the order the engine applies is the whole list's.
final rulePositionsProvider = Provider<Map<String, int>>((ref) {
  final rules = ref.watch(rulesControllerProvider).value ?? const <Rule>[];
  return {for (final (index, rule) in rules.indexed) rule.id: index + 1};
});
