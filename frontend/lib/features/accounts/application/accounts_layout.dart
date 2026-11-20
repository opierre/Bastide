import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/current_user_provider.dart';
import '../data/accounts_layout_store.dart';
import '../domain/account.dart';
import '../domain/account_group.dart';
import 'accounts_controller.dart';
import 'linked_cards.dart';

/// The accounts panel's layout: how its rows are grouped and which sections
/// the user closed.
@immutable
class AccountsLayout {
  const AccountsLayout({
    this.grouping = AccountsGrouping.byType,
    this.collapsed = const {},
  });

  final AccountsGrouping grouping;

  /// Ids of the closed sections ([AccountGroup.id]). Every section is open on
  /// a first visit.
  final Set<String> collapsed;

  bool isOpen(String sectionId) => !collapsed.contains(sectionId);

  AccountsLayout copyWith({
    AccountsGrouping? grouping,
    Set<String>? collapsed,
  }) => AccountsLayout(
    grouping: grouping ?? this.grouping,
    collapsed: collapsed ?? this.collapsed,
  );
}

/// Holds [AccountsLayout] and remembers it per user on this device
/// (`docs/design/05-accounts.md` §Behaviour).
///
/// The saved layout loads after the first frame, which shows the default
/// (by type, all open); a choice made before it arrives wins over it.
class AccountsLayoutController extends Notifier<AccountsLayout> {
  bool _groupingChosen = false;
  bool _collapsedChosen = false;

  @override
  AccountsLayout build() {
    unawaited(_load());
    return const AccountsLayout();
  }

  String? _userId() {
    try {
      return ref.read(currentUserProvider)?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final userId = _userId();
    if (userId == null) return;
    try {
      final store = ref.read(accountsLayoutStoreProvider);
      final grouping = await store.readGrouping(userId);
      final collapsed = await store.readCollapsed(userId);
      if (!ref.mounted) return;
      state = state.copyWith(
        grouping: grouping == null || _groupingChosen
            ? null
            : AccountsGrouping.fromStorage(grouping),
        collapsed: collapsed == null || _collapsedChosen
            ? null
            : collapsed.toSet(),
      );
    } catch (_) {
      // An unreadable store leaves the default layout.
    }
  }

  void setGrouping(AccountsGrouping grouping) {
    _groupingChosen = true;
    if (grouping == state.grouping) return;
    state = state.copyWith(grouping: grouping);
    _save(
      (store, userId) => store.writeGrouping(userId, grouping.storageValue),
    );
  }

  void toggleSection(String sectionId) {
    _collapsedChosen = true;
    final collapsed = {...state.collapsed};
    if (!collapsed.remove(sectionId)) collapsed.add(sectionId);
    state = state.copyWith(collapsed: collapsed);
    _save((store, userId) => store.writeCollapsed(userId, collapsed.toList()));
  }

  void _save(
    Future<void> Function(AccountsLayoutStore store, String userId) write,
  ) {
    final userId = _userId();
    if (userId == null) return;
    unawaited(() async {
      try {
        await write(ref.read(accountsLayoutStoreProvider), userId);
      } catch (_) {
        // The panel already follows the choice; it is only forgotten at the
        // next visit, which is not worth interrupting the user for.
      }
    }());
  }
}

final accountsLayoutProvider =
    NotifierProvider.autoDispose<AccountsLayoutController, AccountsLayout>(
      AccountsLayoutController.new,
    );

/// The panel's sections under the current grouping, over the accounts that
/// get a row of their own ([panelAccounts]).
final accountGroupsProvider = Provider.autoDispose<List<AccountGroup>>(
  (ref) => groupAccounts(
    ref.watch(panelAccountsProvider),
    ref.watch(accountsLayoutProvider.select((layout) => layout.grouping)),
  ),
);

/// The total line's figures.
@immutable
class AccountsSummary {
  const AccountsSummary({
    required this.totalMinor,
    required this.count,
    required this.currency,
  });

  final int totalMinor;

  /// Every live account, with or without a row of its own.
  final int count;
  final String currency;
}

/// The total balance and the account count; `null` while the list loads,
/// fails or is empty.
///
/// Summing is safe because every account shares the user's single currency
/// (see the multi-currency skill); multi-currency would need FX here.
final accountsSummaryProvider = Provider.autoDispose<AccountsSummary?>((ref) {
  final accounts = [
    for (final account
        in ref.watch(accountsControllerProvider).value ?? const <Account>[])
      if (!account.archived) account,
  ];
  if (accounts.isEmpty) return null;
  return AccountsSummary(
    // Deferred cards stay out, as they do from net worth: the account a card
    // is paid from settles what it owes, and counting both would take a
    // month's card spending off the total twice.
    totalMinor: accounts
        .where((account) => account.type != AccountType.deferredCard)
        .fold<int>(0, (sum, account) => sum + account.balanceMinor),
    count: accounts.length,
    currency: accounts.first.currency,
  );
});

/// The clock the accounts panel reads « soldes recalculés il y a … » and the
/// current month from. A provider so tests can pin it.
final accountsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
