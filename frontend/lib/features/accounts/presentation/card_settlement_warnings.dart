import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../application/settlement_rule_controller.dart';
import '../domain/account.dart';
import '../domain/card_settlement_status.dart';
import 'account_form.dart';
import 'settlement_rule_dialog.dart';

/// One warning per deferred card whose purchases may not count exactly once,
/// each with the action that fixes it: choose the account the card is paid
/// from, create its settlement rule, or check that rule.
///
/// Shown on the accounts panel and with an import's result. Silent while
/// loading, when every card counts once, and when the status can't be read —
/// it qualifies the panel it sits on and must never be what breaks it.
class CardSettlementWarnings extends ConsumerWidget {
  const CardSettlementWarnings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(cardSettlementStatusProvider).value;
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    if (issues == null || issues.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in issues)
          if (accounts.where((a) => a.id == issue.accountId).firstOrNull
              case final card?)
            _CardWarning(card: card, issue: issue),
      ],
    );
  }
}

class _CardWarning extends ConsumerWidget {
  const _CardWarning({required this.card, required this.issue});

  final Account card;
  final CardSettlementIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    final (message, action) = switch (issue.kind) {
      CardSettlementIssueKind.noSettlementAccount => (
        l10n.cardSettlementNoAccount(card.name),
        l10n.cardSettlementChooseAccount,
      ),
      CardSettlementIssueKind.noRule => (
        l10n.cardSettlementNoRule(card.name),
        l10n.cardSettlementCreateRule,
      ),
      CardSettlementIssueKind.unsettled => (
        l10n.cardSettlementUnsettled(
          issue.count ?? 0,
          card.name,
          formatAmount(
            amountMinor: (issue.amountMinor ?? 0).abs(),
            currency: card.currency,
            locale: locale,
          ),
          issue.since ?? DateTime.now(),
        ),
        l10n.cardSettlementCheckRule,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineBanner(
            key: Key('cardSettlementWarning-${card.id}'),
            message: message,
            tone: BannerTone.warning,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: Key('cardSettlementAction-${card.id}'),
              onPressed: () async {
                if (issue.kind == CardSettlementIssueKind.noSettlementAccount) {
                  await showAccountForm(context, initial: card);
                } else {
                  await showSettlementRuleDialog(context, card);
                }
                if (context.mounted) {
                  ref.invalidate(cardSettlementStatusProvider);
                }
              },
              child: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}
