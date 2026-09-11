import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/accounts_controller.dart';
import '../../categories/application/categories_controller.dart';
import '../../categorization/application/run_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../goals/application/goals_controller.dart';
import '../../imports/application/imports_controller.dart';
import '../../recurring/application/subscriptions_controller.dart';
import '../../rules/application/rules_controller.dart';
import '../../transactions/application/transactions_controller.dart';

/// Drops every cached view of the user's data, so each reloads on next read.
///
/// Both Données actions that replace the whole profile at once — restoring a
/// backup and resetting the database — leave every one of these describing data
/// that no longer exists. One list, so neither can forget a panel the other
/// remembers.
void reloadUserData(Ref ref) {
  ref
    ..invalidate(accountsControllerProvider)
    ..invalidate(transactionsControllerProvider)
    ..invalidate(dashboardControllerProvider)
    ..invalidate(categoriesControllerProvider)
    ..invalidate(rulesControllerProvider)
    ..invalidate(subscriptionsControllerProvider)
    ..invalidate(seriesDetailProvider)
    ..invalidate(goalsControllerProvider)
    ..invalidate(goalAllocationsProvider)
    ..invalidate(importsControllerProvider)
    ..invalidate(runControllerProvider)
    ..invalidate(aiAvailabilityProvider);
}
