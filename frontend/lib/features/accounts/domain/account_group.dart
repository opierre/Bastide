import 'package:flutter/foundation.dart';

import 'account.dart';

/// How the accounts panel splits its rows into sections
/// (`docs/design/05-accounts.md`).
enum AccountsGrouping {
  byType('type'),
  byInstitution('institution');

  const AccountsGrouping(this.storageValue);

  /// What the preference store keeps, stable across renames of the enum.
  final String storageValue;

  static AccountsGrouping fromStorage(String? value) =>
      AccountsGrouping.values.firstWhere(
        (grouping) => grouping.storageValue == value,
        orElse: () => AccountsGrouping.byType,
      );
}

/// The « Par type » sections, in the order the panel shows them.
enum AccountTypeGroup {
  checking,
  savings,
  deferredCard,
  credit,
  other;

  static AccountTypeGroup of(AccountType type) => switch (type) {
    AccountType.checking => checking,
    AccountType.savings => savings,
    AccountType.deferredCard => deferredCard,
    AccountType.credit => credit,
    AccountType.cash || AccountType.other => other,
  };
}

/// One section of the accounts panel: its rows, subtotal and share.
///
/// Exactly one of [typeGroup] and [institution] is set, depending on the
/// grouping; [institution] is the empty string for the accounts that name
/// none (« Sans établissement »).
@immutable
class AccountGroup {
  const AccountGroup({
    required this.id,
    required this.accounts,
    required this.subtotalMinor,
    required this.sharePercent,
    this.typeGroup,
    this.institution,
  });

  /// Stable across reloads: what the remembered open/closed state keys on.
  final String id;
  final AccountTypeGroup? typeGroup;
  final String? institution;

  /// The section's rows, in list order.
  final List<Account> accounts;

  /// Sum of the rows' balances, signed.
  final int subtotalMinor;

  /// The group's part of the sum of positive subtotals, in percent, always
  /// zero or more (`05-accounts.md` §Groups « Par type »).
  final double sharePercent;

  bool get hasNoInstitution => institution != null && institution!.isEmpty;
}

/// Splits [rows] (the accounts the panel gives a row of their own) into the
/// sections of [grouping].
///
/// « Par type » keeps the fixed order of [AccountTypeGroup] and drops empty
/// groups. « Par établissement » orders institutions by descending subtotal,
/// with « Sans établissement » last whatever its subtotal: it is not an
/// institution, and ranking it among them would read as one.
List<AccountGroup> groupAccounts(
  List<Account> rows,
  AccountsGrouping grouping,
) {
  final buckets = <String, List<Account>>{};
  final typeGroups = <String, AccountTypeGroup>{};
  final institutions = <String, String>{};

  for (final account in rows) {
    switch (grouping) {
      case AccountsGrouping.byType:
        final group = AccountTypeGroup.of(account.type);
        final id = 'type:${group.name}';
        typeGroups[id] = group;
        (buckets[id] ??= []).add(account);
      case AccountsGrouping.byInstitution:
        final name = account.institution.trim();
        final id = 'institution:$name';
        institutions[id] = name;
        (buckets[id] ??= []).add(account);
    }
  }

  int subtotal(List<Account> accounts) =>
      accounts.fold<int>(0, (sum, account) => sum + account.balanceMinor);

  final subtotals = {
    for (final entry in buckets.entries) entry.key: subtotal(entry.value),
  };
  final positiveSum = subtotals.values
      .where((value) => value > 0)
      .fold<int>(0, (sum, value) => sum + value);

  // A negative group shows its share in absolute value, so every share reads
  // as a part of the same whole.
  double share(int subtotalMinor) =>
      positiveSum == 0 ? 0 : subtotalMinor.abs() * 100 / positiveSum;

  final ids = buckets.keys.toList();
  switch (grouping) {
    case AccountsGrouping.byType:
      ids.sort((a, b) => typeGroups[a]!.index.compareTo(typeGroups[b]!.index));
    case AccountsGrouping.byInstitution:
      ids.sort((a, b) {
        final aNone = institutions[a]!.isEmpty;
        final bNone = institutions[b]!.isEmpty;
        if (aNone != bNone) return aNone ? 1 : -1;
        final bySubtotal = subtotals[b]!.compareTo(subtotals[a]!);
        if (bySubtotal != 0) return bySubtotal;
        return institutions[a]!.compareTo(institutions[b]!);
      });
  }

  return [
    for (final id in ids)
      AccountGroup(
        id: id,
        typeGroup: typeGroups[id],
        institution: institutions[id],
        accounts: List.unmodifiable(buckets[id]!),
        subtotalMinor: subtotals[id]!,
        sharePercent: share(subtotals[id]!),
      ),
  ];
}
