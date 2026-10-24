import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/accounts_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../networth/application/networth_controller.dart';

/// Drops the views outside the transaction list that a corrected card
/// settlement changed.
///
/// Correcting a detected settlement does more than restate one row's
/// category: the server removes the credit it posted on the card, so the card
/// balance, net worth and the dashboard (which now counts the debit as
/// spending) describe a ledger that no longer exists. The list itself is the
/// caller's to refresh — it is the controller making the correction.
///
/// Invalidated rather than refreshed, as in
/// `rules/application/recategorized_reload.dart`: those panels are usually
/// unmounted here, so this costs a request only if something is watching.
void invalidateSettlementViews(Ref ref) {
  ref
    ..invalidate(accountsControllerProvider)
    ..invalidate(networthControllerProvider)
    ..invalidate(dashboardControllerProvider);
}
