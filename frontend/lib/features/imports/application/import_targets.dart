import '../../accounts/domain/account.dart';
import 'ofx_account_detection.dart';

/// One statement of the staged file and the account it will be imported into.
typedef ImportTarget = ({String? statement, Account account});

/// The account [match] lands in: the one it resolved to, else the one the
/// user picked to settle a statement that couldn't name its own.
///
/// `null` while the question is open. Deliberately without a "first account"
/// fallback: the panel has no destination selector, so a default here would
/// file a statement against an account nobody chose and nothing on screen
/// would say so.
Account? destinationOf(
  OfxAccountMatch match,
  Map<String?, String> chosen,
  List<Account> accounts,
) => switch (match) {
  OfxAccountMatched(:final account) => account,
  OfxAccountAmbiguous() || OfxAccountUnreadable() =>
    accounts.where((a) => a.id == chosen[statementKey(match)]).firstOrNull,
  OfxAccountUnmatched() || OfxFileUnreadable() => null,
};

/// The statements whose destination another statement of the file also
/// lands in: always a mistake, and the backend would silently keep only the
/// first. Each of them is blocked until the user picks apart.
Set<String?> statementsSharingDestination(
  List<OfxAccountMatch> matches,
  Map<String?, String> chosen,
  List<Account> accounts,
) {
  final byAccount = <String, List<String?>>{};
  for (final match in matches) {
    final account = destinationOf(match, chosen, accounts);
    if (account == null) continue;
    byAccount.putIfAbsent(account.id, () => []).add(statementKey(match));
  }
  return {
    for (final statements in byAccount.values)
      if (statements.length > 1) ...statements,
  };
}

/// What one statement line imports into, or `null` when it can't import yet:
/// no destination, or one shared with another statement of the file.
///
/// Pure so the rule is testable on its own, and shared by the line's button
/// and the import action so what is shown and what is imported into can't
/// diverge.
ImportTarget? importTargetFor(
  OfxAccountMatch match,
  List<OfxAccountMatch> matches,
  Map<String?, String> chosen,
  List<Account> accounts,
) {
  final account = destinationOf(match, chosen, accounts);
  if (account == null) return null;
  final statement = statementKey(match);
  if (statementsSharingDestination(
    matches,
    chosen,
    accounts,
  ).contains(statement)) {
    return null;
  }
  return (statement: statement, account: account);
}
