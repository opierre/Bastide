import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';
import 'accounts_controller.dart';

/// The accounts search query, typed into the top bar's search pill.
///
/// It lives in `application/` rather than in the screen because the control and
/// the list it filters are in different subtrees — the pill is rendered by the
/// shell's top bar, the grid by the panel — so they can only meet in a provider.
class AccountsQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final accountsQueryProvider = NotifierProvider<AccountsQuery, String>(
  AccountsQuery.new,
);

/// The account list narrowed by the current query.
///
/// Filtering is client-side: the whole list is already loaded (the backend has
/// no search parameter, and a user's account count is small enough that paging
/// it would be inventing a problem).
final filteredAccountsProvider = Provider<AsyncValue<List<Account>>>((ref) {
  final accounts = ref.watch(accountsControllerProvider);
  final query = ref.watch(accountsQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return accounts;

  return accounts.whenData(
    (list) => list
        .where(
          (account) =>
              account.name.toLowerCase().contains(query) ||
              account.institution.toLowerCase().contains(query),
        )
        .toList(),
  );
});
