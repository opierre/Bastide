import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/networth_repository.dart';
import '../domain/networth_summary.dart';

/// The Synthèse summary: read-only, re-read whole whenever something it sums
/// changes.
///
/// Never patched locally. A property write invalidates it (see
/// `PropertiesController`) so the figure follows in the same interaction,
/// computed by the server rather than adjusted from the rows the panel holds.
class NetworthController extends AsyncNotifier<NetWorthSummary> {
  @override
  Future<NetWorthSummary> build() =>
      ref.watch(networthRepositoryProvider).summary();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(networthRepositoryProvider).summary(),
    );
  }
}

final networthControllerProvider =
    AsyncNotifierProvider<NetworthController, NetWorthSummary>(
      NetworthController.new,
    );

/// The two views the panel's segmented control switches between.
enum NetworthView { summary, properties }

/// Which view the panel shows. Panel state rather than a route: both views
/// share the chrome and the « Nouveau bien » control.
class NetworthViewController extends Notifier<NetworthView> {
  @override
  NetworthView build() => NetworthView.summary;

  void set(NetworthView view) => state = view;
}

final networthViewProvider =
    NotifierProvider<NetworthViewController, NetworthView>(
      NetworthViewController.new,
    );

/// The spans the « Patrimoine net » card can show, counted back from the
/// series' last month. `null` months: the whole history.
enum NetworthRange {
  year(12),
  threeYears(36),
  all(null);

  const NetworthRange(this.months);

  final int? months;
}

/// Which span the series card shows. Panel state: the API always returns the
/// whole history, so switching re-reads nothing.
class NetworthRangeController extends Notifier<NetworthRange> {
  @override
  NetworthRange build() => NetworthRange.year;

  void set(NetworthRange range) => state = range;
}

final networthRangeProvider =
    NotifierProvider<NetworthRangeController, NetworthRange>(
      NetworthRangeController.new,
    );

/// The points of [series] inside [range]: the last `range.months` calendar
/// months ending with the series' own last month, so a gap still counts as
/// time passed.
List<NetWorthPoint> pointsInRange(
  List<NetWorthPoint> series,
  NetworthRange range,
) {
  final months = range.months;
  if (months == null || series.isEmpty) return series;
  int index(DateTime month) => month.year * 12 + month.month - 1;
  final last = index(series.last.month);
  return [
    for (final point in series)
      if (last - index(point.month) < months) point,
  ];
}

/// The month-end totals the user declared for the time before their imports.
///
/// Each write re-reads the list and invalidates the summary, so the chart
/// shows the server's merge of ledger and declared months — never a local one.
class DeclaredBalancesController extends AsyncNotifier<List<DeclaredBalance>> {
  NetworthRepository get _repository => ref.read(networthRepositoryProvider);

  @override
  Future<List<DeclaredBalance>> build() =>
      ref.watch(networthRepositoryProvider).declared();

  /// Declares, or replaces, [month]'s total. Failures are rethrown for the
  /// modal, which shows them beside the field to change.
  Future<void> declare(DateTime month, int amountMinor) async {
    await _repository.declare(month, amountMinor);
    await _afterWrite();
  }

  Future<void> remove(DateTime month) async {
    await _repository.removeDeclared(month);
    await _afterWrite();
  }

  Future<void> _afterWrite() async {
    ref.invalidate(networthControllerProvider);
    state = await AsyncValue.guard(_repository.declared);
  }
}

final declaredBalancesControllerProvider =
    AsyncNotifierProvider<DeclaredBalancesController, List<DeclaredBalance>>(
      DeclaredBalancesController.new,
    );
