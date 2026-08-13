import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rules_repository.dart';
import '../domain/rule.dart';

/// The priority-ordered rule list.
///
/// Reordering and enabling are **optimistic**: the list moves under the
/// pointer, the patches follow, and a failure puts the previous order back with
/// the error raised to the caller. A drag that visibly snapped back after a
/// round trip would read as a broken list even when the write succeeded.
class RulesController extends AsyncNotifier<List<Rule>> {
  @override
  Future<List<Rule>> build() => ref.read(rulesRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(rulesRepositoryProvider).list());
  }

  /// Creates a rule. A new rule is filed last by default — it has to fall
  /// through the existing set to be worth adding — unless the caller pins a
  /// [priority] itself.
  Future<Rule> create({
    required RuleMatchField matchField,
    required RuleMatchType matchType,
    required String pattern,
    required String categoryId,
    bool enabled = true,
    int? priority,
  }) async {
    final rules = state.value ?? const <Rule>[];
    final created = await ref
        .read(rulesRepositoryProvider)
        .create(
          priority: priority ?? rules.length + 1,
          matchField: matchField,
          matchType: matchType,
          pattern: pattern,
          categoryId: categoryId,
          enabled: enabled,
        );
    state = AsyncValue.data(_sorted([...rules, created]));
    return created;
  }

  Future<Rule> updateRule(
    String id, {
    RuleMatchField? matchField,
    RuleMatchType? matchType,
    String? pattern,
    String? categoryId,
    bool? enabled,
    int? priority,
  }) async {
    final updated = await ref
        .read(rulesRepositoryProvider)
        .update(
          id,
          matchField: matchField,
          matchType: matchType,
          pattern: pattern,
          categoryId: categoryId,
          enabled: enabled,
          priority: priority,
        );
    state = AsyncValue.data(
      _sorted([
        for (final rule in state.value ?? const <Rule>[])
          if (rule.id == id) updated else rule,
      ]),
    );
    return updated;
  }

  Future<void> delete(String id) async {
    await ref.read(rulesRepositoryProvider).delete(id);
    state = AsyncValue.data([
      for (final rule in state.value ?? const <Rule>[])
        if (rule.id != id) rule,
    ]);
  }

  /// Moves the rule at [oldIndex] to [newIndex] and renumbers the list `1..n`.
  ///
  /// Only the rules whose priority actually changed are patched — dragging the
  /// last rule up one place is two writes, not twenty — and the whole move is
  /// rolled back if any of them fails, because a half-applied reorder is an
  /// evaluation order neither the user nor the list is showing.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final previous = state.value;
    if (previous == null || oldIndex == newIndex) return;

    final moved = [...previous];
    final rule = moved.removeAt(oldIndex);
    moved.insert(newIndex, rule);

    final renumbered = [
      for (final (index, entry) in moved.indexed) entry.copyWith(priority: index + 1),
    ];
    state = AsyncValue.data(renumbered);

    final byId = {for (final entry in previous) entry.id: entry};
    try {
      for (final entry in renumbered) {
        if (byId[entry.id]?.priority == entry.priority) continue;
        await ref.read(rulesRepositoryProvider).update(entry.id, priority: entry.priority);
      }
    } catch (_) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  /// Flips a rule's `enabled` flag, optimistically.
  Future<void> setEnabled(String id, bool enabled) async {
    final previous = state.value;
    if (previous == null) return;

    state = AsyncValue.data([
      for (final rule in previous)
        if (rule.id == id) rule.copyWith(enabled: enabled) else rule,
    ]);

    try {
      await ref.read(rulesRepositoryProvider).update(id, enabled: enabled);
    } catch (_) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  /// Re-runs the rules over existing transactions and returns the count the
  /// toast reports.
  Future<int> apply() => ref.read(rulesRepositoryProvider).apply();

  /// Priority order, as the backend lists them — kept locally so an optimistic
  /// insert lands where the next reload would put it.
  List<Rule> _sorted(List<Rule> rules) =>
      [...rules]..sort((a, b) => a.priority.compareTo(b.priority));
}

final rulesControllerProvider = AsyncNotifierProvider<RulesController, List<Rule>>(
  RulesController.new,
);
