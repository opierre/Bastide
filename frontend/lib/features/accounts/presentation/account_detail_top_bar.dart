import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/account_detail_controller.dart';
import '../domain/account.dart';
import 'account_archive.dart';
import 'account_form.dart';
import 'settlement_rule_dialog.dart';

/// The account detail's top-bar title: the account's name, over « Comptes ›
/// `institution` » where « Comptes » leads back to the list.
class AccountDetailTitle extends ConsumerWidget {
  const AccountDetailTitle({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final account = ref.watch(accountByIdProvider(accountId));
    final secondary = textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: AppColors.textSecondary,
    );

    return Column(
      key: const Key('accountDetailTitle'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account?.name ?? '',
          style: textTheme.titleLarge,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            InkWell(
              key: const Key('accountDetailBreadcrumb'),
              onTap: () => context.go('/accounts'),
              child: Text(
                l10n.navAccounts,
                style: secondary?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.borderDashed,
                ),
              ),
            ),
            if (account != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '›',
                  style: secondary?.copyWith(color: AppColors.textDisabled),
                ),
              ),
              Flexible(
                child: Text(
                  account.institution,
                  style: secondary,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

enum _DetailAction { settlementRule }

/// The account detail's contextual controls: edit the account in the existing
/// modal and archive it (never delete), both one click away. A card adds an
/// overflow holding its settlement rule.
class AccountDetailTopBarActions extends ConsumerWidget {
  const AccountDetailTopBarActions({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(accountByIdProvider(accountId));
    if (account == null) return const SizedBox.shrink();

    final pillStyle = TextButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      minimumSize: const Size(0, AppChrome.controlPillHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      shape: const StadiumBorder(),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const Key('accountDetailEdit'),
          onPressed: () async {
            await showAccountForm(context, initial: account);
            ref.invalidate(accountOverviewProvider(account.id));
          },
          style: pillStyle,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(l10n.accountEdit),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton.icon(
          key: const Key('accountDetailArchive'),
          onPressed: () => _archive(context, ref, account),
          style: pillStyle,
          icon: const Icon(Icons.inventory_2_outlined, size: 16),
          label: Text(l10n.accountArchive),
        ),
        if (account.type == AccountType.deferredCard) ...[
          const SizedBox(width: AppSpacing.sm),
          PopupMenuButton<_DetailAction>(
            key: const Key('accountDetailMore'),
            tooltip: l10n.accountDetailMoreActions,
            position: PopupMenuPosition.under,
            onSelected: (action) => switch (action) {
              _DetailAction.settlementRule => _editSettlementRule(
                context,
                ref,
                account,
              ),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('accountDetailSettlementRule'),
                value: _DetailAction.settlementRule,
                child: Text(l10n.accountSettlementRule),
              ),
            ],
            child: Container(
              width: AppChrome.controlPillHeight,
              height: AppChrome.controlPillHeight,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _editSettlementRule(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final saved = await showSettlementRuleDialog(context, account);
    if (saved) ref.invalidate(accountOverviewProvider(account.id));
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final archived = await confirmArchiveAccount(context, ref, account);
    // An archived account has no detail to stay on.
    if (archived && context.mounted) context.go('/accounts');
  }
}
