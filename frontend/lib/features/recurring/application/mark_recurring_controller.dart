import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_controller.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_series.dart';
import '../domain/series_preview.dart';
import 'subscriptions_controller.dart';

/// The « Marquer comme récurrent » dialog's state: what the server proposed,
/// and which of its transactions the user still has ticked.
@immutable
class MarkRecurringState {
  const MarkRecurringState({required this.outcome, required this.ticked});

  final PreviewOutcome outcome;

  /// Ids of the ticked transactions. Every one starts ticked.
  final Set<String> ticked;

  /// The ticked transactions, oldest first — what the summary describes and
  /// what saving links.
  List<PreviewTransaction> get selected => switch (outcome) {
    Proposal(:final preview) => [
      for (final transaction in preview.transactions)
        if (ticked.contains(transaction.id)) transaction,
    ],
    AlreadyInSeries() => const [],
  };

  MarkRecurringState withTicked(Set<String> ticked) =>
      MarkRecurringState(outcome: outcome, ticked: ticked);
}

/// Loads the preview for one transaction and saves the series built from the
/// ticked part of it.
///
/// Auto-disposed and keyed by the transaction: each opening of the dialog asks
/// the server afresh, since an import or a detection pass may have moved the
/// answer since the last time.
class MarkRecurringController extends AsyncNotifier<MarkRecurringState> {
  MarkRecurringController(this.transactionId);

  final String transactionId;

  @override
  Future<MarkRecurringState> build() async {
    final outcome = await ref
        .read(recurringRepositoryProvider)
        .preview(transactionId);
    return MarkRecurringState(
      outcome: outcome,
      ticked: switch (outcome) {
        Proposal(:final preview) => {
          for (final transaction in preview.transactions) transaction.id,
        },
        AlreadyInSeries() => const {},
      },
    );
  }

  /// Ticks or unticks one transaction of the proposal.
  void toggle(String id) {
    final current = state.value;
    if (current == null) return;
    final ticked = {...current.ticked};
    if (!ticked.remove(id)) ticked.add(id);
    state = AsyncValue.data(current.withTicked(ticked));
  }

  /// Creates the series from the ticked transactions and refreshes the two
  /// panels that show it. Failures are rethrown for the dialog to show inline.
  Future<RecurringSeries> save() async {
    final current = state.requireValue;
    final preview = (current.outcome as Proposal).preview;
    final created = await ref
        .read(subscriptionsControllerProvider.notifier)
        .create(
          label: preview.label,
          accountId: preview.accountId,
          expectedAmountMinor: preview.expectedAmountMinor,
          cadence: preview.cadence,
          transactionIds: [
            for (final transaction in current.selected) transaction.id,
          ],
        );
    ref.invalidate(transactionsControllerProvider);
    return created;
  }
}

final markRecurringControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MarkRecurringController, MarkRecurringState, String>(
      MarkRecurringController.new,
    );
