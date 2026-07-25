import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/institution_avatar.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('addAccountButton'),
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.accountsAddButton),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: switch (accountsState) {
              AsyncData(:final value) => value.isEmpty
                  ? _EmptyState(onAdd: () => _openForm(context))
                  : _AccountsList(
                      accounts: value,
                      onEdit: (account) => _openForm(context, initial: account),
                      onArchive: (account) => _confirmArchive(context, ref, l10n, account),
                    ),
              AsyncError(:final error) => _ErrorState(
                message: localizeAccountError(l10n, error),
                onRetry: () => ref.read(accountsControllerProvider.notifier).refresh(),
              ),
              _ => const Center(key: Key('accountsLoadingIndicator'), child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
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

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.accounts, required this.onEdit, required this.onArchive});

  final List<Account> accounts;
  final ValueChanged<Account> onEdit;
  final ValueChanged<Account> onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      key: const Key('accountsList'),
      itemCount: accounts.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
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
  const _AccountCard({required this.account, required this.l10n, required this.onEdit, required this.onArchive});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('accountCard-${account.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            InstitutionAvatar(name: account.institution),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${account.institution} · ${_typeLabel(account.type)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            AmountText(amountMinor: account.balanceMinor, currency: account.currency),
            PopupMenuButton<_AccountAction>(
              key: Key('accountMenu-${account.id}'),
              onSelected: (action) => switch (action) {
                _AccountAction.edit => onEdit(),
                _AccountAction.archive => onArchive(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: _AccountAction.edit, child: Text(l10n.accountEdit)),
                PopupMenuItem(value: _AccountAction.archive, child: Text(l10n.accountArchive)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.accountsEmptyTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.accountsEmptyBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('emptyStateAddAccountButton'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.accountsAddButton),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.negative),
          const SizedBox(height: AppSpacing.md),
          Text(message, key: const Key('accountsErrorText'), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('accountsRetryButton'),
            onPressed: onRetry,
            child: Text(l10n.accountsRetry),
          ),
        ],
      ),
    );
  }
}
