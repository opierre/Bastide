import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/linked_cards.dart';
import '../domain/account.dart';
import 'settlement_rule_dialog.dart';

/// The status after an account's name in the accounts table
/// (`docs/design/05-accounts.md` §Section): `credit-card` and « 1 carte »,
/// opening the linked-cards menu. Each card keeps its own actions there; the
/// account's own edit and archive live in its detail's title bar. Renders
/// nothing when no card is settled on the account.
class LinkedCardsButton extends ConsumerWidget {
  const LinkedCardsButton({
    super.key,
    required this.account,
    required this.onEditCard,
    required this.onArchiveCard,
  });

  final Account account;
  final ValueChanged<Account> onEditCard;
  final ValueChanged<Account> onArchiveCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cards = ref.watch(linkedCardsProvider(account.id));
    if (cards.isEmpty) return const SizedBox.shrink();
    final label = l10n.accountsCardCount(cards.length);
    final iconColor = context.colors.textSecondary;

    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: [
        for (final card in cards)
          SubmenuButton(
            key: Key('linkedCard-${card.id}'),
            leadingIcon: Icon(
              LucideIcons300.creditCard,
              size: AppSizes.iconSmall,
              color: iconColor,
            ),
            menuChildren: [
              _CardAction(
                key: Key('linkedCardEdit-${card.id}'),
                icon: LucideIcons300.pencil,
                label: l10n.accountEdit,
                onPressed: () => onEditCard(card),
              ),
              if (card.type == AccountType.deferredCard)
                _CardAction(
                  key: Key('linkedCardSettlementRule-${card.id}'),
                  icon: LucideIcons300.listChecks,
                  label: l10n.accountSettlementRule,
                  onPressed: () => showSettlementRuleDialog(context, card),
                ),
              // Archive, never delete: a card's transactions are history.
              _CardAction(
                key: Key('linkedCardArchive-${card.id}'),
                icon: LucideIcons300.archive,
                label: l10n.accountArchive,
                onPressed: () => onArchiveCard(card),
              ),
            ],
            child: Text(card.name),
          ),
      ],
      builder: (context, controller, _) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: Key('accountLinkedCards-${account.id}'),
            behavior: HitTestBehavior.opaque,
            // The row under it opens the account; this opens the cards only.
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: StatusText(label: label, icon: LucideIcons300.creditCard),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: Icon(
        icon,
        size: AppSizes.iconSmall,
        color: context.colors.textSecondary,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
