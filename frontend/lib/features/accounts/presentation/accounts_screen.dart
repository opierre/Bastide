import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../domain/account.dart';
import 'account_error_localizer.dart';
import 'account_form.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  static const path = '/accounts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsState = ref.watch(accountsControllerProvider);

    return Padding(
      key: const Key('screen-accounts'),
      padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
      child: switch (accountsState) {
        AsyncData(:final value) when value.isEmpty => _EmptyState(
          onAdd: () => _openForm(context),
        ),
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryHeader(accounts: value, onAdd: () => _openForm(context)),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: _AccountsList(
                accounts: value,
                onEdit: (account) => _openForm(context, initial: account),
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

  void _openForm(BuildContext context, {Account? initial}) {
    showDialog<void>(context: context, builder: (_) => AccountForm(initial: initial));
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

/// Total balance across the listed accounts, plus the add-account action.
/// Summing is safe in Phase 1 because every account shares the user's single
/// currency (see the multi-currency skill); this needs FX before Phase 4.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.accounts, required this.onAdd});

  final List<Account> accounts;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final total = accounts.fold<int>(0, (sum, account) => sum + account.balanceMinor);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountsTotalBalanceLabel.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                AmountText(
                  key: const Key('accountsTotalBalance'),
                  amountMinor: total,
                  currency: accounts.first.currency,
                  // A total is a standing figure, not an inflow or an outflow,
                  // so the income/expense colors would misread here.
                  colorize: false,
                  style: textTheme.headlineMedium!,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.accountsActiveCount(accounts.length),
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            key: const Key('addAccountButton'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.accountsAddButton),
          ),
        ],
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({
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
    return ListView.separated(
      key: const Key('accountsList'),
      itemCount: accounts.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
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

  String _typeLabel(AccountType type) => switch (type) {
    AccountType.checking => l10n.accountTypeChecking,
    AccountType.savings => l10n.accountTypeSavings,
    AccountType.credit => l10n.accountTypeCredit,
    AccountType.cash => l10n.accountTypeCash,
    AccountType.other => l10n.accountTypeOther,
  };

  IconData _typeIcon(AccountType type) => switch (type) {
    AccountType.checking => Icons.account_balance_wallet_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.credit => Icons.credit_card_rounded,
    AccountType.cash => Icons.payments_outlined,
    AccountType.other => Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      key: Key('accountCard-${account.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      onTap: onEdit,
      child: Row(
        children: [
          InstitutionAvatar(name: account.institution, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Row(
                  children: [
                    AppChip(
                      label: _typeLabel(account.type),
                      icon: _typeIcon(account.type),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        account.institution,
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AmountText(
            amountMinor: account.balanceMinor,
            currency: account.currency,
            style: tabularNumberStyle(textTheme.titleMedium!),
          ),
          const SizedBox(width: AppSpacing.xs),
          PopupMenuButton<_AccountAction>(
            key: Key('accountMenu-${account.id}'),
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            position: PopupMenuPosition.under,
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
                child: _MenuRow(icon: Icons.inventory_2_outlined, label: l10n.accountArchive),
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
      icon: Icons.account_balance_outlined,
      title: l10n.accountsEmptyTitle,
      message: l10n.accountsEmptyBody,
      action: FilledButton.icon(
        key: const Key('emptyStateAddAccountButton'),
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.accountsAddButton),
      ),
    );
  }
}
