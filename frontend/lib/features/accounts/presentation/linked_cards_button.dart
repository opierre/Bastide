import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/linked_cards.dart';
import '../domain/account.dart';
import 'settlement_rule_dialog.dart';

/// The account card's corner control: a card icon and how many cards are
/// settled from the account, opening the list of them. Each card keeps its own
/// actions there — the account's own edit and archive live in its detail's
/// top bar. Renders nothing when no card hangs off the account.
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
    final label = l10n.accountLinkedCards(cards.length);

    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: [
        for (final card in cards)
          SubmenuButton(
            key: Key('linkedCard-${card.id}'),
            leadingIcon: const Icon(
              Icons.credit_card_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            menuChildren: [
              _CardAction(
                key: Key('linkedCardEdit-${card.id}'),
                icon: Icons.edit_outlined,
                label: l10n.accountEdit,
                onPressed: () => onEditCard(card),
              ),
              if (card.type == AccountType.deferredCard)
                _CardAction(
                  key: Key('linkedCardSettlementRule-${card.id}'),
                  icon: Icons.rule_rounded,
                  label: l10n.accountSettlementRule,
                  onPressed: () => showSettlementRuleDialog(context, card),
                ),
              // Archive, never delete: a card's transactions are history.
              _CardAction(
                key: Key('linkedCardArchive-${card.id}'),
                icon: Icons.inventory_2_outlined,
                label: l10n.accountArchive,
                onPressed: () => onArchiveCard(card),
              ),
            ],
            child: Text(card.name),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            key: Key('accountLinkedCards-${account.id}'),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            hoverColor: AppColors.overlayWash,
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.credit_card_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${cards.length}',
                    style: tabularNumberStyle(
                      Theme.of(context).textTheme.bodySmall!,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
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
      leadingIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
