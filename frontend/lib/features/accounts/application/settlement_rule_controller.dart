import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/application/recategorized_reload.dart';
import '../../rules/application/rules_controller.dart';
import '../data/accounts_repository.dart';
import '../domain/card_settlement_status.dart';
import '../domain/settlement_rule.dart';

/// The user's deferred cards that don't yet count exactly once, and why.
///
/// Auto-disposed, so the panels showing it read it afresh each time they open:
/// what it reports changes from the account form, the rule dialog and imports.
final cardSettlementStatusProvider =
    FutureProvider.autoDispose<List<CardSettlementIssue>>(
      (ref) => ref.read(accountsRepositoryProvider).settlementStatus(),
    );

/// A card's settlement rule and its proposal, fetched for the dialog that
/// shows them. `autoDispose.family`: read only while that dialog is open.
final settlementRuleProvider = FutureProvider.autoDispose
    .family<SettlementRuleState, String>(
      (ref, cardId) =>
          ref.read(accountsRepositoryProvider).settlementRule(cardId),
    );

/// Saves a card's settlement rule and refreshes what it changed.
class SettlementRuleController {
  SettlementRuleController(this._ref);

  final Ref _ref;

  /// Resolves to how many imported rows the rule filed as a settlement. The
  /// rows it moved left the spending figures and the transaction list stale,
  /// and the rule list gained or changed a rule.
  Future<int> save(String cardId, String pattern) async {
    final moved = await _ref
        .read(accountsRepositoryProvider)
        .saveSettlementRule(cardId, pattern.trim());
    _ref
      ..invalidate(settlementRuleProvider(cardId))
      ..invalidate(cardSettlementStatusProvider)
      ..invalidate(rulesControllerProvider);
    await reloadRecategorizedViews(_ref);
    return moved;
  }
}

final settlementRuleControllerProvider = Provider<SettlementRuleController>(
  SettlementRuleController.new,
);
