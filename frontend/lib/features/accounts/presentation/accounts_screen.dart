import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../application/accounts_search.dart';
import '../domain/account.dart';
import 'account_error_localizer.dart';
import 'account_form.dart';
import 'account_type_label.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  static const path = '/accounts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = ref.watch(filteredAccountsProvider);
    final isSearching = ref.watch(accountsQueryProvider).trim().isNotEmpty;

    return Padding(
      key: const Key('screen-accounts'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: switch (filtered) {
        // An empty result while searching is not an empty account list — the
        // summary stays put so the user keeps their bearings, and only the grid
        // reports the miss.
        AsyncData(:final value) when value.isEmpty && isSearching => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SummaryCard(),
            const SizedBox(height: AppSpacing.gridGap),
            Expanded(
              child: Center(
                child: Text(
                  l10n.accountsSearchEmpty,
                  key: const Key('accountsSearchEmpty'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
        AsyncData(:final value) when value.isEmpty => _EmptyState(
          onAdd: () => showAccountForm(context),
        ),
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SummaryCard(),
            const SizedBox(height: AppSpacing.gridGap),
            Expanded(
              child: _AccountsGrid(
                accounts: value,
                onEdit: (account) => showAccountForm(context, initial: account),
                onArchive: (account) => _confirmArchive(context, ref, l10n, account),
              ),
            ),
          ],
        ),
        AsyncError(:final error) => ErrorStateView(
          message: localizeAccountError(l10n, error),
          messageKey: const Key('accountsErrorText'),
          retryLabel: l10n.accountsRetry,
          retryKey: const Key('accountsRetryButton'),
          onRetry: () => ref.read(accountsControllerProvider.notifier).refresh(),
        ),
        _ => const Padding(
          key: Key('accountsLoadingIndicator'),
          padding: EdgeInsets.only(top: 92),
          child: SkeletonList(),
        ),
      },
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountArchiveConfirmTitle),
        content: Text(l10n.accountArchiveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.accountFormCancel),
          ),
          FilledButton(
            key: const Key('accountArchiveConfirmButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.accountArchive),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(accountsControllerProvider.notifier).archive(account.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizeAccountError(l10n, error))));
    }
  }
}

/// Total balance across the accounts, with the account count, currency and the
/// timestamp the balances were last derived at.
///
/// It reads the *unfiltered* list: a total that changed as you typed in the
/// search box would be a different number than the one the label promises.
/// Summing is safe in Phase 1 because every account shares the user's single
/// currency (see the multi-currency skill); this needs FX before Phase 4.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsControllerProvider).value ?? const <Account>[];
    if (accounts.isEmpty) return const SizedBox.shrink();

    final total = accounts.fold<int>(0, (sum, account) => sum + account.balanceMinor);
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
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.accountsBalancesAsOf(asOf),
                style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
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
    required this.onEdit,
    required this.onArchive,
  });

  final List<Account> accounts;
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
        // Two lines of identity above a footer row; fixed so every card in the
        // grid is the same height regardless of how long its name runs.
        mainAxisExtent: 132,
      ),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return _AccountCard(
          account: account,
          l10n: l10n,
          onEdit: () => onEdit(account),
          onArchive: () => onArchive(account),
        );
      },
    );
  }
}

enum _AccountAction { edit, archive }

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.l10n,
    required this.onEdit,
    required this.onArchive,
  });

  final Account account;
  final AppLocalizations l10n;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      key: Key('accountCard-${account.id}'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      onTap: onEdit,
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
                  _AccountAction.archive => onArchive(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _AccountAction.edit,
                    child: _MenuRow(icon: Icons.edit_outlined, label: l10n.accountEdit),
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
