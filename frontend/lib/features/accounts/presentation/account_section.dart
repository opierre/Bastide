import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/account.dart';
import '../domain/account_group.dart';
import 'linked_cards_button.dart';

/// One section of the accounts panel (`docs/design/05-accounts.md`
/// §Section): the header bar, which is the toggle, and the group's table
/// 10 px below it while open.
class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.group,
    required this.open,
    required this.currency,
    required this.month,
    required this.onToggle,
    required this.onOpenAccount,
    required this.onEditCard,
    required this.onArchiveCard,
  });

  final AccountGroup group;
  final bool open;
  final String currency;

  /// The current month, for the variation column's header.
  final DateTime month;
  final VoidCallback onToggle;
  final ValueChanged<Account> onOpenAccount;
  final ValueChanged<Account> onEditCard;
  final ValueChanged<Account> onArchiveCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final columns = [
      AppTableColumn(label: l10n.accountsColumnAccount, flex: 3),
      AppTableColumn(label: l10n.accountsColumnInstitution, flex: 2),
      AppTableColumn(label: l10n.accountsColumnLastImport, flex: 2),
      AppTableColumn(
        label: l10n.accountsColumnMonthChange(
          DateFormat.MMMM(locale).format(month),
        ),
        flex: 2,
        numeric: true,
      ),
      AppTableColumn(label: l10n.accountsColumnBalance, flex: 2, numeric: true),
    ];

    return Column(
      key: Key('accountSection-${group.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          group: group,
          open: open,
          currency: currency,
          onToggle: onToggle,
        ),
        if (open) ...[
          const SizedBox(height: AppAccountSection.tableGap),
          AppTableHeader(columns: columns),
          for (final account in group.accounts)
            _AccountRow(
              account: account,
              columns: columns,
              onTap: () => onOpenAccount(account),
              onEditCard: onEditCard,
              onArchiveCard: onArchiveCard,
            ),
        ],
      ],
    );
  }
}

/// The section's name, under either grouping.
String accountGroupName(AppLocalizations l10n, AccountGroup group) =>
    switch (group.typeGroup) {
      AccountTypeGroup.checking => l10n.accountsGroupChecking,
      AccountTypeGroup.savings => l10n.accountsGroupSavings,
      AccountTypeGroup.deferredCard => l10n.accountsGroupDeferredCards,
      AccountTypeGroup.credit => l10n.accountsGroupCredits,
      AccountTypeGroup.other => l10n.accountsGroupOther,
      null =>
        group.hasNoInstitution
            ? l10n.accountsNoInstitution
            : group.institution ?? '',
    };

IconData _typeIcon(AccountTypeGroup group) => switch (group) {
  AccountTypeGroup.checking => LucideIcons300.landmark,
  AccountTypeGroup.savings => LucideIcons300.piggyBank,
  AccountTypeGroup.deferredCard => LucideIcons300.creditCard,
  AccountTypeGroup.credit => LucideIcons300.handCoins,
  AccountTypeGroup.other => LucideIcons300.wallet,
};

/// The header bar: 1 px `line`, radius 8 (top corners only while open),
/// `rail` ground, padding 10 12. Chevron, type icon or institution monogram,
/// name 13/600, count, then the share and the subtotal in its 120 px slot.
class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.group,
    required this.open,
    required this.currency,
    required this.onToggle,
  });

  final AccountGroup group;
  final bool open;
  final String currency;
  final VoidCallback onToggle;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final group = widget.group;
    final name = accountGroupName(l10n, group);
    const radius = Radius.circular(AppRadii.container);
    final borderRadius = widget.open
        ? const BorderRadius.vertical(top: radius)
        : const BorderRadius.all(radius);
    final typeGroup = group.typeGroup;

    final bar = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppAccountSection.headerPaddingX,
        vertical: AppAccountSection.headerPaddingY,
      ),
      decoration: BoxDecoration(
        color: colors.rail,
        border: Border.all(color: colors.line),
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          Icon(
            widget.open
                ? LucideIcons300.chevronDown
                : LucideIcons300.chevronRight,
            key: Key(
              widget.open
                  ? 'accountSectionOpen-${group.id}'
                  : 'accountSectionClosed-${group.id}',
            ),
            size: AppSizes.iconSmall,
            color: colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          if (typeGroup != null)
            Icon(
              _typeIcon(typeGroup),
              size: AppSizes.iconSmall,
              color: colors.textSecondary,
            )
          else
            MonogramAvatar(
              name: group.hasNoInstitution ? '' : group.institution ?? '',
            ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${group.accounts.length}',
            style: tabularNumberStyle(
              textTheme.bodyMedium!,
            ).copyWith(color: colors.textTertiary),
          ),
          const Spacer(),
          Text(
            l10n.accountsGroupShare(group.sharePercent),
            key: Key('accountSectionShare-${group.id}'),
            maxLines: 1,
            style: tabularNumberStyle(
              textTheme.bodySmall!,
            ).copyWith(color: colors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: AppAccountSection.subtotalWidth,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AmountText(
                  key: Key('accountSectionSubtotal-${group.id}'),
                  amountMinor: group.subtotalMinor,
                  currency: widget.currency,
                  // A subtotal is a standing figure: neutral, signed only
                  // when negative (`00` §2.3).
                  colorize: false,
                  style: textTheme.titleSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      expanded: widget.open,
      label: name,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: Key('accountSectionHeader-${group.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggle,
          child: FocusRing(
            focused: _focused,
            radius: AppRadii.container,
            child: bar,
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.columns,
    required this.onTap,
    required this.onEditCard,
    required this.onArchiveCard,
  });

  final Account account;
  final List<AppTableColumn> columns;
  final VoidCallback onTap;
  final ValueChanged<Account> onEditCard;
  final ValueChanged<Account> onArchiveCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final secondary = TextStyle(color: colors.textSecondary);
    final lastImport = account.lastImportAt;
    final change = account.monthChangeMinor;

    return AppTableRow(
      key: Key('accountRow-${account.id}'),
      columns: columns,
      onTap: onTap,
      cells: [
        Row(
          children: [
            MonogramAvatar(name: account.institution),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            LinkedCardsButton(
              account: account,
              onEditCard: onEditCard,
              onArchiveCard: onArchiveCard,
            ),
          ],
        ),
        Text(account.institution, style: secondary),
        Text(
          lastImport == null
              ? l10n.accountsNoImport
              : DateFormat.yMMMd(locale).format(lastImport.toLocal()),
          key: Key('accountLastImport-${account.id}'),
          style: secondary,
        ),
        AmountText(
          key: Key('accountMonthChange-${account.id}'),
          amountMinor: change,
          currency: account.currency,
          showPositiveSign: true,
          maxLines: 1,
          // A month with no movement reads as nothing to see.
          style: change == 0 ? TextStyle(color: colors.textTertiary) : null,
        ),
        AmountText(
          key: Key('accountBalance-${account.id}'),
          amountMinor: account.balanceMinor,
          currency: account.currency,
          maxLines: 1,
          // Neutral with its sign; `negative` only below zero (`00` §2.3).
          colorize: false,
          style: account.balanceMinor < 0
              ? TextStyle(color: colors.negative)
              : null,
        ),
      ],
    );
  }
}
