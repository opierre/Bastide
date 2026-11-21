import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../networth/application/networth_controller.dart';
import '../data/placements_repository.dart';
import '../domain/investment.dart';

/// How many stale-value banners the list pane shows before « et {n} autres »
/// (`17-placements.md` §List pane 3).
const staleBannerLimit = 3;

/// Everything the Placements panel's list renders: the placements, the
/// summary line, and the last panel action that failed.
///
/// [actionError] lives inside the data, as on Objectifs: a refused delete
/// says nothing about the placements on screen.
@immutable
class PlacementsState {
  const PlacementsState({
    required this.investments,
    required this.summary,
    this.actionError,
  });

  /// Open placements first, closed ones last (the API's order).
  final List<Investment> investments;
  final InvestmentSummary summary;
  final Object? actionError;

  /// The open placements whose value is older than the stale limit.
  List<Investment> get stale => [
    for (final investment in investments)
      if (investment.valueStale && !investment.isClosed) investment,
  ];

  /// The placement the inspector shows for a selection of [id]: that one
  /// when it exists, else the first of the table.
  Investment? selectedIn(String? id) =>
      investments.where((investment) => investment.id == id).firstOrNull ??
      investments.firstOrNull;

  PlacementsState copyWith({
    Object? actionError,
    bool clearActionError = false,
  }) => PlacementsState(
    investments: investments,
    summary: summary,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );
}

/// The Placements panel's state. Every write reloads: each figure on the
/// panel is derived server-side, so the client never patches one itself.
///
/// Writes issued from a form rethrow, so the form shows the failure where
/// the user can fix it; writes issued from the panel (delete, reopen) land
/// in [PlacementsState.actionError].
class PlacementsController extends AsyncNotifier<PlacementsState> {
  PlacementsRepository get _repository =>
      ref.read(placementsRepositoryProvider);

  @override
  Future<PlacementsState> build() => _load();

  Future<PlacementsState> _load() async {
    final investments = await _repository.list();
    final summary = await _repository.summary();
    return PlacementsState(investments: investments, summary: summary);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  /// Reloads after a write without the loading silhouette: the panel stays
  /// on screen while the figures come back.
  Future<void> _reload(String? investmentId) async {
    if (investmentId != null) {
      ref.invalidate(placementDetailProvider(investmentId));
    }
    // A placement counts in the net worth at its last declared value.
    ref.invalidate(networthControllerProvider);
    state = await AsyncValue.guard(_load);
  }

  Future<InvestmentDetail> create({
    required String name,
    required String institution,
    required Envelope envelope,
    required DateTime openedOn,
    int? initialPaymentsMinor,
    int? initialValueMinor,
  }) async {
    final created = await _repository.create(
      name: name,
      institution: institution,
      envelope: envelope,
      openedOn: openedOn,
      initialPaymentsMinor: initialPaymentsMinor,
      initialValueMinor: initialValueMinor,
    );
    ref.read(selectedPlacementProvider.notifier).select(created.investment.id);
    await _reload(created.investment.id);
    return created;
  }

  Future<void> updatePlacement(
    String id, {
    required String name,
    required String institution,
    required Envelope envelope,
    required DateTime openedOn,
  }) async {
    await _repository.update(
      id,
      name: name,
      institution: institution,
      envelope: envelope,
      openedOn: openedOn,
    );
    await _reload(id);
  }

  Future<void> close(
    String id, {
    required DateTime closedOn,
    required int finalAmountMinor,
  }) async {
    await _repository.close(
      id,
      closedOn: closedOn,
      finalAmountMinor: finalAmountMinor,
    );
    await _reload(id);
  }

  Future<void> reopen(String id) =>
      _panelWrite(id, () => _repository.reopen(id));

  /// Deletes a placement and its whole history. A failure lands in the
  /// panel's banner; the confirmation closes either way.
  Future<void> delete(String id) =>
      _panelWrite(null, () => _repository.delete(id));

  Future<void> addMovement(
    String id, {
    required DateTime occurredOn,
    required int amountMinor,
    String? note,
    String? transactionId,
  }) async {
    await _repository.addMovement(
      id,
      occurredOn: occurredOn,
      amountMinor: amountMinor,
      note: note,
      transactionId: transactionId,
    );
    await _reload(id);
  }

  Future<void> updateMovement(
    String id,
    String movementId, {
    required DateTime occurredOn,
    required int amountMinor,
    String? note,
    String? transactionId,
  }) async {
    await _repository.updateMovement(
      id,
      movementId,
      occurredOn: occurredOn,
      amountMinor: amountMinor,
      note: note,
      transactionId: transactionId,
    );
    await _reload(id);
  }

  Future<void> deleteMovement(String id, String movementId) async {
    await _repository.deleteMovement(id, movementId);
    await _reload(id);
  }

  Future<void> addValuation(
    String id, {
    required DateTime valuedOn,
    required int valueMinor,
    String? note,
  }) async {
    await _repository.addValuation(
      id,
      valuedOn: valuedOn,
      valueMinor: valueMinor,
      note: note,
    );
    await _reload(id);
  }

  Future<void> updateValuation(
    String id,
    String valuationId, {
    required DateTime valuedOn,
    required int valueMinor,
    String? note,
  }) async {
    await _repository.updateValuation(
      id,
      valuationId,
      valuedOn: valuedOn,
      valueMinor: valueMinor,
      note: note,
    );
    await _reload(id);
  }

  Future<void> deleteValuation(String id, String valuationId) async {
    await _repository.deleteValuation(id, valuationId);
    await _reload(id);
  }

  void clearActionError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(clearActionError: true));
  }

  Future<void> _panelWrite(String? id, Future<void> Function() write) async {
    final current = state.value;
    if (current == null) return;
    try {
      await write();
      await _reload(id);
    } on ApiFailure catch (failure) {
      state = AsyncValue.data(current.copyWith(actionError: failure));
    }
  }
}

final placementsControllerProvider =
    AsyncNotifierProvider<PlacementsController, PlacementsState>(
      PlacementsController.new,
    );

/// One placement with its history, for the inspector. Invalidated by every
/// write on that placement.
final placementDetailProvider = FutureProvider.family<InvestmentDetail, String>(
  (ref, id) {
    return ref.watch(placementsRepositoryProvider).detail(id);
  },
);

/// The arguments of one link-candidates lookup.
typedef LinkQuery = ({
  String investmentId,
  int amountMinor,
  DateTime on,
  String? movementId,
});

/// Imported transfers that may have funded a movement of that amount.
final linkCandidatesProvider = FutureProvider.autoDispose
    .family<List<LinkCandidate>, LinkQuery>((ref, query) {
      return ref
          .watch(placementsRepositoryProvider)
          .linkCandidates(
            query.investmentId,
            amountMinor: query.amountMinor,
            on: query.on,
            movementId: query.movementId,
          );
    });

/// The placement the user picked in the table, or `null` before they pick
/// one; read through [PlacementsState.selectedIn].
class SelectedPlacement extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedPlacementProvider = NotifierProvider<SelectedPlacement, String?>(
  SelectedPlacement.new,
);
