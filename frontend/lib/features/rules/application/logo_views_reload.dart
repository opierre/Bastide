import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/dashboard_controller.dart';
import '../../recurring/application/subscriptions_controller.dart';
import '../../transactions/application/transactions_controller.dart';

/// Re-reads every view that shows a merchant chip after a change to which
/// logo the rows show: a rule's logo uploaded, replaced or removed, or a rule
/// carrying one edited, reordered, disabled or deleted.
///
/// The backend resolves each row's logo when it is read, so the rows already
/// loaded still name the old one until they are fetched again. Quietly, like
/// `reloadRecategorizedViews`: the user is in the rule editor, and nothing
/// here may fail the change that triggered it.
Future<void> reloadLogoViews(Ref ref) async {
  // Only views that are loaded: one that isn't reads fresh rows when it opens.
  if (ref.exists(transactionsControllerProvider)) {
    await ref.read(transactionsControllerProvider.notifier).refreshQuietly();
  }
  // The account detail's recent operations re-read on this.
  ref.read(transactionEditsProvider.notifier).saved();
  if (ref.exists(subscriptionsControllerProvider)) {
    await ref.read(subscriptionsControllerProvider.notifier).refreshQuietly();
  }
  ref
    ..invalidate(seriesDetailProvider)
    ..invalidate(dashboardControllerProvider);
}
