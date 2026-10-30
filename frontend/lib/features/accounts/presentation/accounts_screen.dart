import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../domain/account.dart';
import 'account_archive.dart';
import 'account_detail_screen.dart';
import 'account_error_localizer.dart';
import 'account_form.dart';
import 'account_type_label.dart';
import 'card_settlement_warnings.dart';
import 'settlement_rule_dialog.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  static const path = '/accounts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsControllerProvider);

    return Padding(
      key: const Key('screen-accounts'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: switch (accounts) {
        AsyncData(:final value) when value.isEmpty => _EmptyState(
          onAdd: () => showAccountForm(context),
        ),
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SummaryCard(),
            // A card whose purchases may count twice says so above the grid,
            // where the fix — its settlement account or rule — is one tap away.
            const CardSettlementWarnings(),
            const SizedBox(height: AppSpacing.gridGap),
            Expanded(
              child: _AccountsGrid(
                accounts: value,
                onOpen: (account) =>
                    context.go(AccountDetailScreen.location(account.id)),
                onEdit: (account) => showAccountForm(context, initial: account),
                onArchive: (account) =>
                    confirmArchiveAccount(context, ref, account),
              ),
            ),
          ],
        ),
        AsyncError(:final error) => ErrorStateView(
          message: localizeAccountError(l10n, error),
          messageKey: const Key('accountsErrorText'),
          retryLabel: l10n.accountsRetry,
          retryKey: const Key('accountsRetryButton'),
          onRetry: () =>
              ref.read(accountsControllerProvider.notifier).refresh(),
        ),
        _ => const Padding(
          key: Key('accountsLoadingIndicator'),
          padding: EdgeInsets.only(top: 92),
          child: SkeletonList(),
        ),
      },
    );
  }
}

/// Total balance across the accounts, with the account count, currency and the
/// timestamp the balances were last derived at.
///
/// Summing is safe because every account shares the user's single currency
/// (see the multi-currency skill); multi-currency would need FX here.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    if (accounts.isEmpty) return const SizedBox.shrink();

    // Deferred cards stay out, as they do from net worth: the account a card
    // is paid from settles what it owes, and counting both would take a
    // month's card spending off the total twice.
    final total = accounts
        .where((account) => account.type != AccountType.deferredCard)
        .fold<int>(0, (sum, account) => sum + account.balanceMinor);
    final currency = accounts.first.currency;
    // The backend has no "balances recalculated at" field yet; the newest
    // account mutation is the closest honest stand-in for it.
    final asOf = accounts
        .map((account) => account.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountsTotalBalanceLabel.toUpperCase(),
                  style: AppTextStyles.sectionLabel,
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                AmountText(
                  key: const Key('accountsTotalBalance'),
                  amountMinor: total,
                  currency: currency,
                  // A total is a standing figure, not an inflow or an outflow,
                  // so the income/expense colors would misread here.
                  colorize: false,
                  style: textTheme.displayLarge!,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${l10n.accountsActiveCount(accounts.length)} · $currency',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.accountsBalancesAsOf(asOf.toLocal()),
                style: AppTextStyles.helper.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountsGrid extends StatelessWidget {
  const _AccountsGrid({
    required this.accounts,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });

  final List<Account> accounts;
  final ValueChanged<Account> onOpen;
  final ValueChanged<Account> onEdit;
  final ValueChanged<Account> onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GridView.builder(
      key: const Key('accountsList'),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.gridGap,
        crossAxisSpacing: AppSpacing.gridGap,
        // Three lines of identity above a footer row; fixed so every card in
        // the grid is the same height regardless of how long its name runs.
        mainAxisExtent: 152,
      ),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return _AccountCard(
          account: account,
          l10n: l10n,
          onOpen: () => onOpen(account),
          onEdit: () => onEdit(account),
          onArchive: () => onArchive(account),
        );
      },
    );
  }
}

enum _AccountAction { edit, settlementRule, archive }

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.l10n,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });

  final Account account;
  final AppLocalizations l10n;

  /// Opens the account's detail — the card's whole face is the way in; editing
  /// stays one step away in its menu.
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      key: Key('accountCard-${account.id}'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InstitutionAvatar(name: account.institution, size: 40),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.institution,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _LastTransaction(account: account, l10n: l10n),
                  ],
                ),
              ),
              PopupMenuButton<_AccountAction>(
                key: Key('accountMenu-${account.id}'),
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
                position: PopupMenuPosition.under,
                // Archive, never delete: an account's transactions are history,
                // and deleting it would take them with it.
                onSelected: (action) => switch (action) {
                  _AccountAction.edit => onEdit(),
                  _AccountAction.settlementRule => showSettlementRuleDialog(
                    context,
                    account,
                  ),
                  _AccountAction.archive => onArchive(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _AccountAction.edit,
                    child: _MenuRow(
                      icon: Icons.edit_outlined,
                      label: l10n.accountEdit,
                    ),
                  ),
                  if (account.type == AccountType.deferredCard)
                    PopupMenuItem(
                      key: Key('accountSettlementRule-${account.id}'),
                      value: _AccountAction.settlementRule,
                      child: _MenuRow(
                        icon: Icons.rule_rounded,
                        label: l10n.accountSettlementRule,
                      ),
                    ),
                  PopupMenuItem(
                    value: _AccountAction.archive,
                    child: _MenuRow(
                      icon: Icons.inventory_2_outlined,
                      label: l10n.accountArchive,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              AppChip(label: accountTypeLabel(l10n, account.type)),
              const SizedBox(width: AppSpacing.sm),
              // The balance is this card's one data point, so it carries the
              // sign colors — unlike the summary total, which stays neutral.
              // It scales down rather than wrapping or clipping: a balance that
              // loses digits is worse than one rendered a point smaller.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: AmountText(
                    amountMinor: account.balanceMinor,
                    currency: account.currency,
                    showPositiveSign: true,
                    style: tabularNumberStyle(textTheme.headlineLarge!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// When the account last moved — read at a glance, it is what singles out the
/// dormant accounts worth archiving.
class _LastTransaction extends StatelessWidget {
  const _LastTransaction({required this.account, required this.l10n});

  final Account account;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final date = account.lastTransactionDate;
    final locale = Localizations.localeOf(context).toString();

    return Text(
      date == null
          ? l10n.accountNoTransactions
          : l10n.accountLastTransaction(DateFormat.yMMMd(locale).format(date)),
      key: Key('accountLastTransaction-${account.id}'),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      icon: Icons.account_balance_wallet_outlined,
      title: l10n.accountsEmptyTitle,
      message: l10n.accountsEmptyBody,
      action: PrimaryButton(
        key: const Key('emptyStateAddAccountButton'),
        label: l10n.accountsAddButton,
        icon: Icons.add_rounded,
        height: 44,
        onPressed: onAdd,
      ),
    );
  }
}
