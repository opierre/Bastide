import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../l10n/app_localizations.dart';
import '../application/account_detail_controller.dart';
import '../domain/account.dart';
import 'account_archive.dart';
import 'account_form.dart';

/// The account detail's title-bar title: « Comptes / » leading back to the
/// list, then the account's name (`docs/design/16-account-detail.md`).
class AccountDetailTitle extends ConsumerWidget {
  const AccountDetailTitle({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(accountByIdProvider(accountId));

    return TitleBarTitle(
      key: const Key('accountDetailTitle'),
      crumb: TitleBarCrumb(
        label: l10n.navAccounts,
        onTap: () => context.go('/accounts'),
      ),
      title: account?.name ?? '',
    );
  }
}

/// The account detail's contextual controls (`16` § Title bar): a secondary
/// « Modifier » opening the account form, then an `ellipsis` button whose
/// menu holds « Archiver ». No delete.
class AccountDetailTopBarActions extends ConsumerStatefulWidget {
  const AccountDetailTopBarActions({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailTopBarActions> createState() =>
      _AccountDetailTopBarActionsState();
}

class _AccountDetailTopBarActionsState
    extends ConsumerState<AccountDetailTopBarActions> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(accountByIdProvider(widget.accountId));
    if (account == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          key: const Key('accountDetailEdit'),
          label: l10n.accountEdit,
          onPressed: () async {
            await showAccountForm(context, initial: account);
            ref.invalidate(accountOverviewProvider(account.id));
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        MenuAnchor(
          controller: _menu,
          style: AppPopover.menuStyle(context),
          alignmentOffset: const Offset(0, AppSpacing.xs),
          menuChildren: [
            AppMenuItem(
              key: const Key('accountDetailArchive'),
              label: l10n.accountArchive,
              leading: const Icon(LucideIcons300.archive),
              onPressed: () => _archive(account),
            ),
          ],
          child: AppButton(
            key: const Key('accountDetailMore'),
            label: l10n.accountDetailMoreActions,
            icon: LucideIcons300.ellipsis,
            iconOnly: true,
            onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
          ),
        ),
      ],
    );
  }

  Future<void> _archive(Account account) async {
    final archived = await confirmArchiveAccount(context, ref, account);
    // An archived account has no detail to stay on.
    if (archived && mounted) context.go('/accounts');
  }
}
