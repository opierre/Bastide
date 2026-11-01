import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_controller.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_series.dart';
import '../domain/series_preview.dart';
import 'subscriptions_controller.dart';

/// The series picker behind « Ajouter à une série existante… »: every series
/// the user has not dismissed, on any account, and the search typed over them.
@immutable
class SeriesPickerState {
  const SeriesPickerState({
    required this.series,
    this.query = '',
    this.selectedId,
  });

  /// Detected, confirmed and cancelled series, by label.
  final List<RecurringSeries> series;
  final String query;

  /// The series the user picked, waiting for « Confirmer ». Kept across a
  /// search that hides it, like the charge picker keeps its ticks.
  final String? selectedId;

  RecurringSeries? get selected =>
      series.where((row) => row.id == selectedId).firstOrNull;

  /// The series whose label contains [query], ignoring case.
  List<RecurringSeries> get visible {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return series;
    return [
      for (final row in series)
        if (row.label.toLowerCase().contains(needle)) row,
    ];
  }

  SeriesPickerState withQuery(String query) =>
      SeriesPickerState(series: series, query: query, selectedId: selectedId);

  SeriesPickerState withSelected(String seriesId) =>
      SeriesPickerState(series: series, query: query, selectedId: seriesId);
}

/// Loads the series a charge can join, holds the one selected, and adds the
/// charge to it once the user confirms.
///
/// Dismissed series are left out: the user said they are not subscriptions,
/// so offering one would ask them to file a charge under a "no". A cancelled
/// one stays, because a late or final charge of an ended subscription is still
/// its charge. Every account is offered, since a subscription can move from
/// one account to another and `attach` accepts a charge from any of them.
class SeriesPickerController extends AsyncNotifier<SeriesPickerState> {
  @override
  Future<SeriesPickerState> build() async {
    final series = await ref.read(recurringRepositoryProvider).list();
    return SeriesPickerState(
      series: [
        for (final row in series)
          if (row.status != SeriesStatus.dismissed) row,
      ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase())),
    );
  }

  void search(String query) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.withQuery(query));
  }

  /// Marks [seriesId] as the one to add the charge to. Nothing is sent: the
  /// dialog's « Confirmer » does that, so a misclick costs nothing.
  void select(String seriesId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.withSelected(seriesId));
  }

  /// Adds [transactionId] to [seriesId]; the server learns its label for the
  /// series. Failures are rethrown for the dialog to report.
  Future<RecurringSeries> pick(String seriesId, String transactionId) async {
    final saved = await ref
        .read(subscriptionsControllerProvider.notifier)
        .attach(seriesId, [transactionId]);
    ref.invalidate(transactionsControllerProvider);
    return saved;
  }
}

final seriesPickerControllerProvider =
    AsyncNotifierProvider.autoDispose<
      SeriesPickerController,
      SeriesPickerState
    >(SeriesPickerController.new);

/// The charge picker behind « Ajouter une opération »: the pages of candidate
/// outflows fetched so far, the search they were fetched under, and the ticks.
@immutable
class ChargePickerState {
  const ChargePickerState({
    required this.items,
    required this.total,
    this.page = 1,
    this.query = '',
    this.ticked = const {},
    this.isLoadingMore = false,
  });

  /// The candidates fetched so far, closest first.
  final List<PreviewTransaction> items;

  /// How many candidates match [query] in all.
  final int total;

  /// The last page fetched, 1-based.
  final int page;
  final String query;

  /// The ticked charges by id. Kept apart from [items] so a tick survives a
  /// search that hides it.
  final Map<String, PreviewTransaction> ticked;
  final bool isLoadingMore;

  bool get hasMore => items.length < total;

  /// The ticked charges, oldest first: the order they are sent in.
  List<PreviewTransaction> get selected =>
      ticked.values.toList()
        ..sort((a, b) => a.bookedDate.compareTo(b.bookedDate));

  ChargePickerState copyWith({
    List<PreviewTransaction>? items,
    int? total,
    int? page,
    String? query,
    Map<String, PreviewTransaction>? ticked,
    bool? isLoadingMore,
  }) => ChargePickerState(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    query: query ?? this.query,
    ticked: ticked ?? this.ticked,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// Pages through the outflows a series could take and adds the ticked ones.
///
/// The server ranks and filters, so the client never scans the ledger: a
/// search refetches the first page, and « Afficher plus » appends the next.
class ChargePickerController extends AsyncNotifier<ChargePickerState> {
  ChargePickerController(this.seriesId);

  final String seriesId;

  RecurringRepository get _repository => ref.read(recurringRepositoryProvider);

  @override
  Future<ChargePickerState> build() => _firstPage('', const {});

  Future<ChargePickerState> _firstPage(
    String query,
    Map<String, PreviewTransaction> ticked,
  ) async {
    final page = await _repository.candidates(seriesId, query: query);
    return ChargePickerState(
      items: page.items,
      total: page.total,
      query: query,
      ticked: ticked,
    );
  }

  /// Refetches the first page under [query], keeping the ticks.
  Future<void> search(String query) async {
    final ticked = state.value?.ticked ?? const {};
    // Riverpod keeps the previous page as the loading state's value.
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _firstPage(query, ticked));
  }

  /// Fetches the next page and appends it. A failure keeps what is shown.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final next = await _repository.candidates(
        seriesId,
        query: current.query,
        page: current.page + 1,
      );
      final known = {for (final item in current.items) item.id};
      state = AsyncValue.data(
        current.copyWith(
          items: [
            ...current.items,
            for (final item in next.items)
              if (!known.contains(item.id)) item,
          ],
          total: next.total,
          page: next.page,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }

  void toggle(PreviewTransaction transaction) {
    final current = state.value;
    if (current == null) return;
    final ticked = {...current.ticked};
    if (ticked.remove(transaction.id) == null) {
      ticked[transaction.id] = transaction;
    }
    state = AsyncValue.data(current.copyWith(ticked: ticked));
  }

  /// Adds the ticked charges to the series and refreshes the panels showing
  /// it. Failures are rethrown for the dialog to show inline.
  Future<RecurringSeries> save() async {
    final ids = [for (final charge in state.requireValue.selected) charge.id];
    final saved = await ref
        .read(subscriptionsControllerProvider.notifier)
        .attach(seriesId, ids);
    ref.invalidate(transactionsControllerProvider);
    return saved;
  }
}

final chargePickerControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChargePickerController, ChargePickerState, String>(
      ChargePickerController.new,
    );
