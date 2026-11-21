import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rules_repository.dart';
import 'rules_controller.dart';

/// How many transactions each rule currently classes, keyed by rule id: the
/// « Correspondances » column of the rules table (`docs/design/08`).
///
/// Watches the rule list, so an edit, a reorder or a toggle counts again: each
/// one changes which rule reaches a row first. A run of the rules invalidates
/// it too (`recategorized_reload.dart`). While a recount is in flight the
/// previous counts stay on screen.
final ruleMatchCountsProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(rulesControllerProvider);
  return ref.read(rulesRepositoryProvider).matchCounts();
});
