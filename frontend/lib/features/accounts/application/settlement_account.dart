import '../domain/account.dart';

/// The accounts a deferred card can be settled from: the user's open current
/// accounts — a card only ever settles against one.
///
/// [currentId] is the card's saved settlement account, kept even when it is
/// not a current account so editing an older card still shows its choice.
List<Account> settlementCandidates(
  List<Account> accounts, {
  String? cardId,
  String? currentId,
}) => [
  for (final account in accounts)
    if (account.id != cardId &&
        !account.archived &&
        (account.type == AccountType.checking ||
            (currentId != null && account.id == currentId)))
      account,
];

/// The settlement account to preselect for a card at [institution], when one
/// answer is obvious: the only current account at that bank, else the only
/// candidate at all. `null` when the user has to choose.
///
/// Only a default — the form shows the choice and the user can change it.
String? proposedSettlementAccountId(
  List<Account> candidates, {
  required String institution,
}) {
  final bank = institution.trim().toLowerCase();
  final sameBankChecking = [
    for (final account in candidates)
      if (account.type == AccountType.checking &&
          bank.isNotEmpty &&
          account.institution.trim().toLowerCase() == bank)
        account,
  ];
  if (sameBankChecking.length == 1) return sameBankChecking.single.id;
  return candidates.length == 1 ? candidates.single.id : null;
}

/// The deferred cards an account's detail can link to it: the user's open
/// cards that have no settlement account yet. A card already settled
/// elsewhere is moved from its own form, not taken over from here.
List<Account> linkableCards(List<Account> accounts) => [
  for (final account in accounts)
    if (account.type == AccountType.deferredCard &&
        !account.archived &&
        account.settlementAccountId == null)
      account,
];
