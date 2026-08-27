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
    this.statusFilter,
    this.actionError,
  }) : rows = _joinSignals(series, summary);

  final List<RecurringSeries> series;
  final RecurringSummary summary;

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
    SeriesStatus? statusFilter,
    bool clearStatusFilter = false,
    Object? actionError,
    bool clearActionError = false,
  }) => SubscriptionsState(
    series: series ?? this.series,
    summary: summary ?? this.summary,
    statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );

  static List<SubscriptionRow> _joinSignals(
    List<RecurringSeries> series,
    RecurringSummary summary,
  ) {
    final increases = {
      for (final increase in summary.priceIncreases) increase.seriesId: increase,
    };
    final missed = {for (final charge in summary.missed) charge.seriesId: charge};

    return [
      for (final row in series)
        SubscriptionRow(series: row, signal: _signalFor(row, increases, missed)),
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
/// server-side over the whole set (`PROJECT.md` §12), and a client that
/// recomputed them from the rows it happens to be showing would drift the
/// moment a filter was applied.
class SubscriptionsController extends AsyncNotifier<SubscriptionsState> {
  RecurringRepository get _repository => ref.read(recurringRepositoryProvider);

  @override
  Future<SubscriptionsState> build() => _load(null);

  Future<SubscriptionsState> _load(SeriesStatus? status) async {
    final series = await _repository.list(status: status);
    final summary = await _repository.summary();
    return SubscriptionsState(series: series, summary: summary, statusFilter: status);
  }

  Future<void> refresh() async {
    final status = state.value?.statusFilter;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(status));
  }

  /// Narrows the list to one lifecycle status, or back to all of them.
  Future<void> setStatusFilter(SeriesStatus? status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(status));
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

  /// Declares a subscription detection has not found. Failures are rethrown:
  /// the form is still open and shows them inline, where the user can fix them.
  Future<RecurringSeries> create({
    required String label,
    required String accountId,
    required int expectedAmountMinor,
    required Cadence cadence,
    String? categoryId,
  }) async {
    final created = await _repository.create(
      label: label,
      accountId: accountId,
      expectedAmountMinor: expectedAmountMinor,
      cadence: cadence,
      categoryId: categoryId,
    );
    await refresh();
    return created;
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
  List<RecurringSeries> _replace(SubscriptionsState current, RecurringSeries updated) {
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
final subscriptionCategoriesByIdProvider = Provider<Map<String, AppCategory>>((ref) {
  final categories = ref.watch(subscriptionCategoriesProvider).value ?? const [];
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
final seriesDetailProvider = FutureProvider.family<SeriesDetail, String>((ref, id) {
  return ref.watch(recurringRepositoryProvider).detail(id);
});
