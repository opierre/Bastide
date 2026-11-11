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
