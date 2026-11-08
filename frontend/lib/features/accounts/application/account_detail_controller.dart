import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_controller.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../data/accounts_repository.dart';
import '../domain/account.dart';
import '../domain/account_overview.dart';
import 'accounts_controller.dart';
import 'settlement_account.dart';

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

/// The account's latest transactions, newest first, its linked cards' purchases
/// among them — card spending is paid from this account, so the list reads
/// incomplete without it. Re-read after a category edit, which the rows' own
/// picker saves outside this provider.
///
/// Both a card's monthly settlement debit and the purchases it pays show here;
/// the settlement rule files the debit as a transfer, and the page's figures
/// (balance, period stats) stay the account's own ledger, so nothing is summed
/// twice.
final recentAccountTransactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, accountId) async {
      ref.watch(transactionEditsProvider);
      final page = await ref
          .read(transactionsRepositoryProvider)
          .list(accountId: accountId, includeLinkedCards: true);
      return page.items.take(recentTransactionCount).toList();
    });

/// The account's linked cards by id, so a card's row — in the recent list, or
/// in the Transactions panel filtered to the account — can name its card. Empty while the overview loads, or for an account without
/// cards.
final linkedCardsByIdProvider = Provider.autoDispose
    .family<Map<String, LinkedCard>, String>((ref, accountId) {
      final overview = ref.watch(accountOverviewProvider(accountId)).value;
      return {
        for (final card in overview?.linkedCards ?? const <LinkedCard>[])
          card.accountId: card,
      };
    });

/// The range the chart shows — balance months, or a card's cycles. Opens on
/// twelve, the window the stats card beside it describes.
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

/// The cards the linked-cards section offers to link: the user's open
/// deferred cards with no settlement account. Empty while the list loads.
final linkableCardsProvider = Provider.autoDispose<List<Account>>((ref) {
  final accounts = ref.watch(accountsControllerProvider).value;
  return accounts == null ? const [] : linkableCards(accounts);
});
