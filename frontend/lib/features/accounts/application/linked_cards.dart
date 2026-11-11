import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';
import 'accounts_controller.dart';

/// The cards settled from the account [accountId]: every live account naming
/// it as its settlement account, in the order the list holds them.
///
/// A card is not a real account — its total lands on the account that pays
/// it — so the accounts panel reaches a card through that account.
List<Account> linkedCards(List<Account> accounts, String accountId) => [
  for (final account in accounts)
    if (account.settlementAccountId == accountId && !account.archived) account,
];

/// [linkedCards] over the loaded accounts list; empty while it loads or fails.
final linkedCardsProvider = Provider.autoDispose.family<List<Account>, String>(
  (ref, accountId) => linkedCards(
    ref.watch(accountsControllerProvider).value ?? const <Account>[],
    accountId,
  ),
);

/// The accounts the panel gives a tile of their own, in list order: every
/// live account except the cards already listed under a shown account's
/// card count (see [linkedCards]).
///
/// A card keeps its tile until it is linked, and also when the account it
/// names is missing, archived or itself hidden — otherwise nothing on the
/// panel would lead to it.
List<Account> panelAccounts(List<Account> accounts) {
  final live = {
    for (final account in accounts)
      if (!account.archived) account.id: account,
  };
  final hidden = <String, bool>{};

  bool isHidden(Account account, Set<String> seen) {
    final known = hidden[account.id];
    if (known != null) return known;
    final parent = live[account.settlementAccountId];
    // A link that loops back stops at the account it started from, which
    // keeps its tile, so the loop is still reached from the panel.
    final result =
        parent != null &&
        seen.add(account.id) &&
        !seen.contains(parent.id) &&
        !isHidden(parent, seen);
    return hidden[account.id] = result;
  }

  return [
    for (final account in accounts)
      if (!account.archived && !isHidden(account, <String>{})) account,
  ];
}

/// [panelAccounts] over the loaded accounts list; empty while it loads or
/// fails.
final panelAccountsProvider = Provider.autoDispose<List<Account>>(
  (ref) => panelAccounts(
    ref.watch(accountsControllerProvider).value ?? const <Account>[],
  ),
);
