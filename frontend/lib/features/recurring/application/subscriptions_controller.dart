import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../categories/domain/category.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_series.dart';
import '../domain/recurring_summary.dart';

/// Everything the subscriptions panel renders in one value: the series, the
/// server-computed summary, the filter they were fetched under, and the last
/// action that failed.
///
/// [actionError] lives *inside* the data rather than turning the whole
/// `AsyncValue` into an error: a rejected lifecycle transition says nothing
/// about the list the user is looking at, and blanking eight rows to report one
/// refused click would lose more than it explained.
@immutable
class SubscriptionsState {
  SubscriptionsState({
    required this.series,
    required this.summary,
    this.archived = const [],
    this.showArchived = false,
    this.mergeSuggestions = const [],
    this.statusFilter,
    this.actionError,
  }) : rows = _joinSignals(series, summary),
       archivedRows = _joinSignals(archived, summary);

  final List<RecurringSeries> series;
  final RecurringSummary summary;

  /// The series the user put away, loaded up front so the reveal link can
  /// state how many there are before anyone clicks it.
  final List<RecurringSeries> archived;

  /// Whether the archived series are revealed under the live ones.
  final bool showArchived;

  /// [archived] as the table draws them. The summary leaves archived series
  /// out, so the only signal one can carry is its own cancelled state.
  final List<SubscriptionRow> archivedRows;

  /// Pairs the server thinks are one subscription the bank renamed. The panel
  /// offers the first; the next appears once the user has answered it.
  final List<MergeSuggestion> mergeSuggestions;

  /// The rows as the table draws them — each series beside whatever the summary
  /// reports about it. Joined once here rather than in the row widget, so the
  /// table stays presentation only.
  final List<SubscriptionRow> rows;

  /// `null` shows every status, which is what the panel does: a cancelled row
  /// is dimmed, not hidden.
  final SeriesStatus? statusFilter;

  /// The last write the panel attempted and the server refused, or `null`.
  final Object? actionError;

  SubscriptionsState copyWith({
    List<RecurringSeries>? series,
    RecurringSummary? summary,
    List<RecurringSeries>? archived,
    bool? showArchived,
    List<MergeSuggestion>? mergeSuggestions,
    SeriesStatus? statusFilter,
    bool clearStatusFilter = false,
    Object? actionError,
    bool clearActionError = false,
  }) => SubscriptionsState(
    series: series ?? this.series,
    summary: summary ?? this.summary,
    archived: archived ?? this.archived,
    showArchived: showArchived ?? this.showArchived,
    mergeSuggestions: mergeSuggestions ?? this.mergeSuggestions,
    statusFilter: clearStatusFilter
        ? null
        : (statusFilter ?? this.statusFilter),
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );

  static List<SubscriptionRow> _joinSignals(
    List<RecurringSeries> series,
    RecurringSummary summary,
  ) {
    final increases = {
      for (final increase in summary.priceIncreases)
        increase.seriesId: increase,
    };
    final missed = {
      for (final charge in summary.missed) charge.seriesId: charge,
    };

    return [
      for (final row in series)
        SubscriptionRow(
          series: row,
          signal: _signalFor(row, increases, missed),
        ),
    ];
  }

  /// A row carries at most one signal, and the order below is the order of
  /// consequence. A cancelled subscription is settled, so nothing the summary
  /// might still say about it applies; a charge that never arrived outranks a
  /// price change, because the missing charge is the newer fact.
  static SeriesSignal? _signalFor(
    RecurringSeries series,
    Map<String, PriceIncrease> increases,
    Map<String, MissedCharge> missed,
  ) {
    if (series.status == SeriesStatus.cancelled) {
      return CancelledSignal(lastChargeOn: series.lastSeenDate);
    }
    if (missed[series.id] case final charge?) {
      return MissedChargeSignal(
        expectedOn: charge.expectedOn,
        daysLate: charge.daysLate,
      );
    }
    if (increases[series.id] case final increase?) {
      return PriceIncreaseSignal(
        // Both amounts come from the series rather than being reconstructed
        // from the delta alone: `expected_amount_minor` is already re-baselined
        // on the newer price, so the previous one is exactly it minus the step.
        previousAmountMinor: series.expectedAmountMinor - increase.deltaMinor,
        currentAmountMinor: series.expectedAmountMinor,
        changedAt: increase.changedAt,
      );
    }
    return null;
  }
}

/// The subscriptions panel's state: the series list and the burden summary,
/// loaded together and kept in step through every write.
///
/// The summary is re-read after each mutation rather than adjusted locally.
/// Every card on it — the burden, the counts, the exclusions — is defined
/// server-side over the whole set, and a client that
/// recomputed them from the rows it happens to be showing would drift the
/// moment a filter was applied.
class SubscriptionsController extends AsyncNotifier<SubscriptionsState> {
  RecurringRepository get _repository => ref.read(recurringRepositoryProvider);

  @override
  Future<SubscriptionsState> build() => _load(null);

  /// [showArchived] is carried over by every reload: it is a view choice, not a
  /// fact about the data, and a reload behind an archive must not fold the
  /// archived list back up under the user.
  Future<SubscriptionsState> _load(
    SeriesStatus? status, {
    bool showArchived = false,
  }) async {
    final (series, archived, summary, suggestions) = await (
      _repository.list(status: status),
      _repository.list(archived: true),
      _repository.summary(),
      _repository.mergeSuggestions(),
    ).wait;
    return SubscriptionsState(
      series: series,
      archived: archived,
      showArchived: showArchived,
      summary: summary,
      mergeSuggestions: suggestions,
      statusFilter: status,
    );
  }

  /// Puts a series away: it leaves the list, the summary and detection, keeps
  /// its status and history, and can be restored from the archived list.
  /// Resolves to whether the server took it; a refusal is kept as
  /// [SubscriptionsState.actionError].
  Future<bool> archive(String seriesId) =>
      _answer(() => _repository.archive(seriesId), seriesId: seriesId);

  /// Brings an archived series back exactly as it was put away.
  Future<bool> unarchive(String seriesId) =>
      _answer(() => _repository.unarchive(seriesId), seriesId: seriesId);

  /// Reveals the archived series under the live ones, or folds them away.
  void toggleArchived() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(showArchived: !current.showArchived),
    );
  }

  /// Folds [suggestion]'s source into its target, then reloads in place: the
  /// list, the summary and the remaining suggestions all change with it.
  /// Resolves to whether the merge went through; a refusal is kept as
  /// [SubscriptionsState.actionError] with the panel left standing.
  Future<bool> merge(MergeSuggestion suggestion) => _answer(
    () => _repository.merge(suggestion.target.id, suggestion.source.id),
  );

  /// Tells the server the two series are distinct subscriptions.
  Future<bool> keepApart(MergeSuggestion suggestion) => _answer(
    () => _repository.keepApart(suggestion.target.id, suggestion.source.id),
  );

  /// Sends the user's answer, then reloads the panel behind it.
  ///
  /// Every failure of the write is kept as [SubscriptionsState.actionError],
  /// not only a refusal from the server: a sidecar that cannot be reached
  /// throws something else, and letting it escape would leave the banner
  /// spinning with nothing said. The reload is a separate step, because once
  /// the write has landed the answer is given — a reload that then fails turns
  /// the panel into its error state with a retry rather than leaving the
  /// answered suggestion on screen as if nothing had happened.
  ///
  /// [seriesId] names the series the write changed, whose open detail is
  /// re-read with it.
  Future<bool> _answer(
    Future<Object?> Function() write, {
    String? seriesId,
  }) async {
    final current = state.value;
    if (current == null) return false;
    try {
      await write();
    } on Object catch (error) {
      state = AsyncValue.data(current.copyWith(actionError: error));
      return false;
    }
    if (seriesId != null) ref.invalidate(seriesDetailProvider(seriesId));
    state = await AsyncValue.guard(
      () => _load(current.statusFilter, showArchived: current.showArchived),
    );
    return true;
  }

  Future<void> refresh() async {
    final status = state.value?.statusFilter;
    final showArchived = state.value?.showArchived ?? false;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _load(status, showArchived: showArchived),
    );
  }

  /// Narrows the list to one lifecycle status, or back to all of them.
  Future<void> setStatusFilter(SeriesStatus? status) async {
    final showArchived = state.value?.showArchived ?? false;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _load(status, showArchived: showArchived),
    );
  }

  /// Moves a series along the lifecycle.
  ///
  /// A refused transition is kept as [SubscriptionsState.actionError] and the
  /// list is left standing. The panel only ever offers legal transitions, but
  /// "the UI can't ask for this" is not the same as "the server will never say
  /// no" — a stale row is enough to produce one.
  Future<void> changeStatus(String seriesId, SeriesStatus status) async {
    final current = state.value;
    if (current == null) return;

    try {
      final updated = await _repository.update(seriesId, status: status);
      final summary = await _repository.summary();
      state = AsyncValue.data(
        current.copyWith(
          series: _replace(current, updated),
          summary: summary,
          clearActionError: true,
        ),
      );
    } on ApiFailure catch (failure) {
      state = AsyncValue.data(current.copyWith(actionError: failure));
    }
  }

  /// Creates a series from [transactionIds], its first occurrences. Failures
  /// are rethrown: the dialog is still open and shows them inline.
  Future<RecurringSeries> create({
    required String label,
    required String accountId,
    required int expectedAmountMinor,
    required Cadence cadence,
    String? categoryId,
    required List<String> transactionIds,
  }) async {
    final created = await _repository.create(
      label: label,
      accountId: accountId,
      expectedAmountMinor: expectedAmountMinor,
      cadence: cadence,
      categoryId: categoryId,
      transactionIds: transactionIds,
    );
    await refresh();
    return created;
  }

  /// Adds transactions to an existing series. Like [create], failures reach
  /// the dialog that asked.
  Future<RecurringSeries> attach(
    String seriesId,
    List<String> transactionIds,
  ) async {
    final updated = await _repository.attach(seriesId, transactionIds);
    ref.invalidate(seriesDetailProvider(seriesId));
    await refresh();
    return updated;
  }

  /// Edits a series' user-owned fields. Like [create], failures reach the form.
  Future<RecurringSeries> updateSeries(
    String seriesId, {
    String? label,
    String? categoryId,
    Cadence? cadence,
    int? expectedAmountMinor,
  }) async {
    final updated = await _repository.update(
      seriesId,
      label: label,
      categoryId: categoryId,
      cadence: cadence,
      expectedAmountMinor: expectedAmountMinor,
    );
    final current = state.value;
    if (current != null) {
      final summary = await _repository.summary();
      state = AsyncValue.data(
        current.copyWith(
          series: _replace(current, updated),
          summary: summary,
          clearActionError: true,
        ),
      );
    }
    return updated;
  }

  Future<void> delete(String seriesId) async {
    await _repository.delete(seriesId);
    await refresh();
  }

  /// Re-runs detection over every account and reloads the panel behind it.
  Future<DetectionResult> detect() async {
    final result = await _repository.detect();
    await refresh();
    return result;
  }

  void clearActionError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(clearActionError: true));
  }

  /// The list with [updated] swapped in — or dropped, when a status change has
  /// moved it out of the filter the list was fetched under.
  List<RecurringSeries> _replace(
    SubscriptionsState current,
    RecurringSeries updated,
  ) {
    final filter = current.statusFilter;
    return [
      for (final row in current.series)
        if (row.id != updated.id)
          row
        else if (filter == null || updated.status == filter)
          updated,
    ];
  }
}

final subscriptionsControllerProvider =
    AsyncNotifierProvider<SubscriptionsController, SubscriptionsState>(
      SubscriptionsController.new,
    );

/// The accounts a series can belong to — the creation form's Compte select, and
/// the name the detail header prints.
final subscriptionAccountsProvider = FutureProvider<List<SeriesAccount>>((ref) {
  return ref.watch(recurringRepositoryProvider).listAccounts();
});

/// The category catalog behind the rows' chips and the form's picker.
final subscriptionCategoriesProvider = FutureProvider<List<AppCategory>>((ref) {
  return ref.watch(recurringRepositoryProvider).listCategories();
});

/// The catalog keyed by id, so a row can resolve its chip without scanning.
final subscriptionCategoriesByIdProvider = Provider<Map<String, AppCategory>>((
  ref,
) {
  final categories =
      ref.watch(subscriptionCategoriesProvider).value ?? const [];
  return {for (final category in categories) category.id: category};
});

/// Which series the panel is showing in detail, or `null` for the list.
///
/// Panel state rather than a route: the detail is a *state of this panel* —
/// same chrome, same top-bar controls, an iris back link instead of a browser
/// step (`docs/design/10` frame ②).
class SelectedSeries extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String seriesId) => state = seriesId;

  void close() => state = null;
}

final selectedSeriesProvider = NotifierProvider<SelectedSeries, String?>(
  SelectedSeries.new,
);

/// One series with the occurrence history it was deduced from.
final seriesDetailProvider = FutureProvider.family<SeriesDetail, String>((
  ref,
  id,
) {
  return ref.watch(recurringRepositoryProvider).detail(id);
});
