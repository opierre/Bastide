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

  /// Every transaction the checklist offers, oldest first.
  List<PreviewTransaction> get candidates => switch (outcome) {
    Proposal(:final preview) => preview.transactions,
    AlreadyInSeries(:final addable) => addable,
  };

  /// The ticked transactions, oldest first — what the summary describes and
  /// what saving links.
  List<PreviewTransaction> get selected => [
    for (final transaction in candidates)
      if (ticked.contains(transaction.id)) transaction,
  ];

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
    final initial = MarkRecurringState(outcome: outcome, ticked: const {});
    return initial.withTicked({
      for (final transaction in initial.candidates) transaction.id,
    });
  }

  /// Ticks or unticks one transaction of the proposal.
  void toggle(String id) {
    final current = state.value;
    if (current == null) return;
    final ticked = {...current.ticked};
    if (!ticked.remove(id)) ticked.add(id);
    state = AsyncValue.data(current.withTicked(ticked));
  }

  /// Creates the series from the ticked transactions — or adds them to the
  /// series that already tracks them — and refreshes the two panels that show
  /// it. Failures are rethrown for the dialog to show inline.
  Future<RecurringSeries> save() async {
    final current = state.requireValue;
    final ids = [for (final transaction in current.selected) transaction.id];
    final subscriptions = ref.read(subscriptionsControllerProvider.notifier);
    final saved = switch (current.outcome) {
      Proposal(:final preview) => await subscriptions.create(
        label: preview.label,
        accountId: preview.accountId,
        expectedAmountMinor: preview.expectedAmountMinor,
        cadence: preview.cadence,
        transactionIds: ids,
      ),
      AlreadyInSeries(:final series) => await subscriptions.attach(
        series.id,
        ids,
      ),
    };
    ref.invalidate(transactionsControllerProvider);
    return saved;
  }
}

final markRecurringControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MarkRecurringController, MarkRecurringState, String>(
      MarkRecurringController.new,
    );
