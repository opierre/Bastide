import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/dashboard_controller.dart';
import '../../transactions/application/transactions_controller.dart';

/// Re-reads every view that shows a category the rules have just rewritten.
///
/// Three actions recategorize existing rows — « Exécuter les règles », a rule
/// learned from a correction with « appliquer maintenant », and a pack imported
/// the same way — and each one leaves the transaction list and the dashboard's
/// répartition describing categories the server no longer holds. One list, as
/// in `settings/application/user_data_reload.dart`, so none of the three can
/// forget a panel the others remember.
///
/// The write itself has already happened when this runs: nothing here is
/// allowed to fail the action, which is why the list refresh is the quiet one.
Future<void> reloadRecategorizedViews(Ref ref) async {
  // Quietly, not [TransactionsController.refresh]: the review queue fires one
  // of these three actions from the list itself, and blanking the rows the user
  // is reading into a skeleton to restate a category is worse than the stale
  // chip it replaces.
  await ref.read(transactionsControllerProvider.notifier).refreshQuietly();

  // Invalidated rather than refreshed: the rules live in the categories panel,
  // so the dashboard is usually unmounted here — this costs a request only if
  // something is actually watching, and otherwise just marks it for the next
  // time the panel opens.
  ref.invalidate(dashboardControllerProvider);
}
