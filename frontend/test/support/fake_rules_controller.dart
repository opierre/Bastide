import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A no-network `RulesController` double for widget tests.
class FakeRulesController extends RulesController {
  FakeRulesController({
    this.initialRules = const [],
    this.loadError,
    this.applyCount = 0,
  });

  final List<Rule> initialRules;
  final Object? loadError;
  final int applyCount;

  final reorderCalls = <({int oldIndex, int newIndex})>[];
  final toggleCalls = <({String id, bool enabled})>[];
  int applyCalls = 0;

  Object? errorOnApply;

  @override
  Future<List<Rule>> build() async {
    if (loadError != null) throw loadError!;
    return initialRules;
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {
    reorderCalls.add((oldIndex: oldIndex, newIndex: newIndex));
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    toggleCalls.add((id: id, enabled: enabled));
    state = AsyncValue.data([
      for (final rule in state.value ?? const <Rule>[])
        if (rule.id == id) rule.copyWith(enabled: enabled) else rule,
    ]);
  }

  @override
  Future<int> apply() async {
    applyCalls++;
    if (errorOnApply != null) throw errorOnApply!;
    return applyCount;
  }
}

Rule testRule({
  String id = 'r1',
  int priority = 1,
  RuleMatchField matchField = RuleMatchField.merchant,
  RuleMatchType matchType = RuleMatchType.contains,
  String pattern = 'CARREFOUR',
  String categoryId = 'groceries',
  bool enabled = true,
}) => Rule(
  id: id,
  priority: priority,
  matchField: matchField,
  matchType: matchType,
  pattern: pattern,
  categoryId: categoryId,
  enabled: enabled,
  createdAt: DateTime.utc(2026, 1, 1),
);
