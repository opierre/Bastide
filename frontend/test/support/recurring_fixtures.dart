import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/recurring_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// May 2026 — the month every mockup and fixture in the project is set in.
final testToday = DateTime(2026, 5, 14);

RecurringSeries testSeries({
  String id = 's1',
  String accountId = 'a1',
  String label = 'Netflix',
  String? categoryId,
  Cadence cadence = Cadence.monthly,
  int expectedAmountMinor = -1549,
  String currency = 'EUR',
  DateTime? firstSeenDate,
  DateTime? lastSeenDate,
  DateTime? nextExpectedDate,
  int occurrenceCount = 5,
  SeriesStatus status = SeriesStatus.detected,
  bool isManual = false,
  int? priceChangeMinor,
  DateTime? priceChangedAt,
}) => RecurringSeries(
  id: id,
  accountId: accountId,
  label: label,
  categoryId: categoryId,
  cadence: cadence,
  medianIntervalDays: 30,
  expectedAmountMinor: expectedAmountMinor,
  currency: currency,
  firstSeenDate: firstSeenDate ?? DateTime(2025, 12, 15),
  lastSeenDate: lastSeenDate ?? DateTime(2026, 4, 15),
  nextExpectedDate: nextExpectedDate ?? DateTime(2026, 5, 15),
  occurrenceCount: occurrenceCount,
  status: status,
  isManual: isManual,
  priceChangeMinor: priceChangeMinor,
  priceChangedAt: priceChangedAt,
);

RecurringSummary testSummary({
  int monthlyTotalMinor = -21208,
  int activeCount = 1,
  int cancelledCount = 0,
  Map<Cadence, int>? cadenceCounts,
  NextCharge? nextCharge,
  List<PriceIncrease> priceIncreases = const [],
  List<MissedCharge> missed = const [],
  String currency = 'EUR',
}) => RecurringSummary(
  monthlyTotalMinor: monthlyTotalMinor,
  activeCount: activeCount,
  cancelledCount: cancelledCount,
  cadenceCounts:
      cadenceCounts ??
      {
        Cadence.weekly: 0,
        Cadence.monthly: activeCount,
        Cadence.quarterly: 0,
        Cadence.yearly: 0,
        Cadence.irregular: 0,
      },
  nextCharge: nextCharge,
  priceIncreases: priceIncreases,
  missed: missed,
  currency: currency,
);

/// A no-network [SubscriptionsController] double for widget tests: a fixed
/// list and summary, plus a record of the lifecycle writes the panel attempted.
class FakeSubscriptionsController extends SubscriptionsController {
  FakeSubscriptionsController({
    this.initialSeries = const [],
    RecurringSummary? summary,
    this.mergeSuggestions = const [],
    this.loadError,
  }) : summary = summary ?? testSummary(activeCount: 0);

  final List<RecurringSeries> initialSeries;
  final RecurringSummary summary;
  final List<MergeSuggestion> mergeSuggestions;
  final Object? loadError;

  final mergeCalls = <MergeSuggestion>[];
  final keepApartCalls = <MergeSuggestion>[];

  final statusCalls = <(String, SeriesStatus)>[];
  final createCalls = <RecurringSeries>[];
  final createTransactionIds = <List<String>>[];
  Object? errorOnStatusChange;
  Object? errorOnCreate;

  @override
  Future<SubscriptionsState> build() async {
    if (loadError != null) throw loadError!;
    return SubscriptionsState(
      series: initialSeries,
      summary: summary,
      mergeSuggestions: mergeSuggestions,
    );
  }

  @override
  Future<bool> merge(MergeSuggestion suggestion) async {
    mergeCalls.add(suggestion);
    _drop(suggestion);
    return true;
  }

  @override
  Future<bool> keepApart(MergeSuggestion suggestion) async {
    keepApartCalls.add(suggestion);
    _drop(suggestion);
    return true;
  }

  void _drop(MergeSuggestion suggestion) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        mergeSuggestions: [
          for (final other in current.mergeSuggestions)
            if (other != suggestion) other,
        ],
      ),
    );
  }

  @override
  Future<RecurringSeries> create({
    required String label,
    required String accountId,
    required int expectedAmountMinor,
    required Cadence cadence,
    String? categoryId,
    List<String> transactionIds = const [],
  }) async {
    if (errorOnCreate != null) throw errorOnCreate!;
    createTransactionIds.add(transactionIds);
    final created = testSeries(
      id: 'created',
      accountId: accountId,
      label: label,
      categoryId: categoryId,
      cadence: cadence,
      expectedAmountMinor: expectedAmountMinor,
      isManual: true,
      occurrenceCount: 0,
    );
    createCalls.add(created);
    return created;
  }

  final attachCalls = <(String, List<String>)>[];

  @override
  Future<RecurringSeries> attach(
    String seriesId,
    List<String> transactionIds,
  ) async {
    attachCalls.add((seriesId, transactionIds));
    return testSeries(id: seriesId);
  }

  @override
  Future<void> changeStatus(String seriesId, SeriesStatus status) async {
    statusCalls.add((seriesId, status));
    final current = state.value;
    if (current == null) return;
    if (errorOnStatusChange != null) {
      state = AsyncValue.data(
        current.copyWith(actionError: errorOnStatusChange),
      );
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        series: [
          for (final row in current.series)
            if (row.id == seriesId)
              testSeries(
                id: row.id,
                label: row.label,
                cadence: row.cadence,
                expectedAmountMinor: row.expectedAmountMinor,
                status: status,
              )
            else
              row,
        ],
        clearActionError: true,
      ),
    );
  }
}
