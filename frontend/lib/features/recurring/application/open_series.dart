import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../transactions/application/transactions_controller.dart';
import '../data/recurring_repository.dart';
import 'subscriptions_controller.dart';

/// Selects a series a transaction row points at, after checking with the
/// server that it still exists.
///
/// The row's series id comes from a list that may be minutes old, and a series
/// deleted in the meantime would open the panel on a 404. The check asks the
/// repository directly rather than reading [seriesDetailProvider]: that
/// provider retries a failure on Riverpod's back-off, so its future would keep
/// the user waiting on a series that is gone. One loopback request is all the
/// happy path adds.
class SeriesOpener {
  const SeriesOpener(this._ref);

  final Ref _ref;

  /// Selects [seriesId] and returns `true`, or returns `false` when the server
  /// says the series is gone.
  ///
  /// On `false` the rows that still point at it are reloaded, so their button
  /// goes back to « Marquer comme récurrent ». Any other failure still selects
  /// the series: the panel has its own error state with a retry.
  Future<bool> open(String seriesId) async {
    try {
      await _ref.read(recurringRepositoryProvider).detail(seriesId);
    } on ApiFailure catch (failure) {
      if (failure.code == 'RECURRING_SERIES_NOT_FOUND') {
        _ref.invalidate(transactionsControllerProvider);
        _ref.read(transactionEditsProvider.notifier).saved();
        return false;
      }
    } catch (_) {
      // Not this method's to report: the panel shows it, with a retry.
    }
    _ref.read(selectedSeriesProvider.notifier).open(seriesId);
    return true;
  }
}

final seriesOpenerProvider = Provider<SeriesOpener>(SeriesOpener.new);
