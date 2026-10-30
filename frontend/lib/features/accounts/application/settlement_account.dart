import '../domain/account.dart';

/// The accounts a deferred card can be settled from: the user's other
/// accounts, cards excepted — a card is paid from where money is.
List<Account> settlementCandidates(List<Account> accounts, {String? cardId}) =>
    [
      for (final account in accounts)
        if (account.id != cardId &&
            !account.archived &&
            account.type != AccountType.deferredCard)
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
