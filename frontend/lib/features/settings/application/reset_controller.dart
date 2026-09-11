import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/database_repository.dart';
import '../domain/database_reset.dart';
import 'user_data_reload.dart';

/// What this profile holds right now.
///
/// Read when the confirmation opens rather than kept with the card: the modal
/// tells the user how many rows are about to go, and a count that was true when
/// the panel loaded is not a claim worth making about a delete.
final databaseSummaryProvider = FutureProvider<DatabaseCounts>((ref) {
  return ref.watch(databaseRepositoryProvider).summary();
});

@immutable
class ResetState {
  const ResetState({this.isResetting = false, this.failure});

  /// The delete is in flight.
  final bool isResetting;

  /// Why the last attempt was refused — shown in the card (⑪ rules). Cleared
  /// when the next attempt starts.
  final ResetFailure? failure;
}

/// The danger zone's reset (`docs/design/09-settings.md` §Zone de danger).
///
/// Nothing here is reachable without the confirmation modal's typed word, which
/// is the only guard: the action takes no argument that could be got wrong, and
/// the server refuses it outright while a categorisation run is writing.
class ResetController extends Notifier<ResetState> {
  @override
  ResetState build() => const ResetState();

  /// Deletes everything this profile owns and returns what went. Throws
  /// [ResetException]; the server is atomic, so a failure leaves the data whole.
  Future<DatabaseCounts> reset() async {
    state = const ResetState(isResetting: true);
    try {
      final deleted = await ref.read(databaseRepositoryProvider).reset();
      reloadUserData(ref);
      // The counts the confirmation was built from are now all zero.
      ref.invalidate(databaseSummaryProvider);
      state = const ResetState();
      return deleted;
    } on ApiFailure catch (failure) {
      final typed = ResetFailure.fromCode(failure.code);
      state = ResetState(failure: typed);
      throw ResetException(typed);
    } catch (error) {
      state = const ResetState(failure: ResetFailure.unknown);
      if (error is ResetException) rethrow;
      throw const ResetException(ResetFailure.unknown);
    }
  }
}

final resetControllerProvider = NotifierProvider<ResetController, ResetState>(
  ResetController.new,
);
