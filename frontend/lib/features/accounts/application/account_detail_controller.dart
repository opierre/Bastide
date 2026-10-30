import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../data/accounts_repository.dart';
import '../domain/account.dart';
import '../domain/account_overview.dart';
import 'accounts_controller.dart';

/// How many of the account's latest transactions the detail panel lists.
const recentTransactionCount = 8;

/// The account detail panel's data, one read per account.
///
/// Auto-disposed: the panel reads it afresh each time it opens, since imports,
/// rules and edits made elsewhere all move what it reports. The panel's own
/// edits — the account form, a settlement rule — invalidate it when they close.
final accountOverviewProvider = FutureProvider.autoDispose
    .family<AccountOverview, String>((ref, accountId) {
      return ref.read(accountsRepositoryProvider).overview(accountId);
    });

/// The account's latest transactions, newest first.
final recentAccountTransactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, accountId) async {
      final page = await ref
          .read(transactionsRepositoryProvider)
          .list(accountId: accountId);
      return page.items.take(recentTransactionCount).toList();
    });

/// The range the balance chart shows. Opens on twelve months, the window the
/// stats card beside it describes.
class BalanceRangeController extends Notifier<BalanceRange> {
  BalanceRangeController(this.accountId);

  final String accountId;

  @override
  BalanceRange build() => BalanceRange.twelveMonths;

  void select(BalanceRange range) => state = range;
}

final balanceRangeControllerProvider = NotifierProvider.autoDispose
    .family<BalanceRangeController, BalanceRange, String>(
      BalanceRangeController.new,
    );

/// The balance points the chart draws for the selected range.
final visibleBalanceHistoryProvider = Provider.autoDispose
    .family<List<BalancePoint>, String>((ref, accountId) {
      final overview = ref.watch(accountOverviewProvider(accountId)).value;
      if (overview == null) return const [];
      final range = ref.watch(balanceRangeControllerProvider(accountId));
      return range.slice(overview.balanceHistory);
    });

/// One of the user's accounts, looked up in the accounts list the panel
/// already holds — a card's paying account, or a linked card the settlement
/// rule dialog opens for. `null` while the list loads, or for no id.
final accountByIdProvider = Provider.autoDispose.family<Account?, String?>((
  ref,
  accountId,
) {
  if (accountId == null) return null;
  final accounts = ref.watch(accountsControllerProvider).value;
  return accounts?.where((account) => account.id == accountId).firstOrNull;
});
