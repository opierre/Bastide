import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/account_detail_controller.dart';
import '../application/accounts_controller.dart';
import '../domain/account.dart';

/// Opens the dialog that links one of the user's unlinked deferred cards to
/// [account], and refreshes the account's detail once one is linked, so the
/// card shows in its section straight away. Resolves to whether one was.
Future<bool> showLinkCardDialog(BuildContext context, Account account) async {
  // Looked up before the await: the section that opened the dialog rebuilds
  // while the overview reloads.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final l10n = AppLocalizations.of(context)!;
  final card = await showAppModal<Account>(
    context: context,
    builder: (_) => LinkCardDialog(account: account),
  );
  if (card == null) return false;
  if (overlay != null && overlay.mounted) {
    showAppToastOn(overlay, title: l10n.linkCardLinked(card.name));
  }
  return true;
}

/// « Lier une carte » (`05-accounts.md`, proposal v6 `m-accounts`): picks the
/// deferred card to settle on [account]. Only cards with no settlement
/// account are offered; linking goes through the same account update the
/// card's own form uses.
class LinkCardDialog extends ConsumerStatefulWidget {
  const LinkCardDialog({super.key, required this.account});

  final Account account;

  @override
  ConsumerState<LinkCardDialog> createState() => _LinkCardDialogState();
}

class _LinkCardDialogState extends ConsumerState<LinkCardDialog> {
  String? _cardId;
  bool _isSaving = false;
  String? _errorText;

  Future<void> _link(List<Account> cards) async {
    final l10n = AppLocalizations.of(context)!;
    final card = cards.where((card) => card.id == _cardId).firstOrNull;
    if (card == null || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await ref
          .read(accountsControllerProvider.notifier)
          .linkCard(card.id, widget.account.id);
      ref.invalidate(accountOverviewProvider(widget.account.id));
      if (mounted) Navigator.of(context).pop(card);
    } catch (_) {
      if (mounted) setState(() => _errorText = l10n.linkCardFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = ref.watch(linkableCardsProvider);
    // A card linked meanwhile (from its own form) drops out of the choice.
    final selected = cards.any((card) => card.id == _cardId) ? _cardId : null;
    final link = selected == null || _isSaving ? null : () => _link(cards);

    return AppModal(
      key: const Key('linkCardModal'),
      width: AppModalSizes.w480,
      title: l10n.linkCardTitle,
      // The introductory sentence is the header's lead (`00` §7, Body).
      subtitle: Text(l10n.linkCardBody(widget.account.name)),
      // A chosen card is unsaved input: the scrim no longer drops it.
      dirty: selected != null,
      busy: _isSaving,
      saveError: _errorText,
      onSubmit: link,
      actions: [
        AppModalCancel(
          key: const Key('linkCardCancelButton'),
          label: l10n.linkCardCancel,
        ),
        PrimaryButton(
          key: const Key('linkCardConfirmButton'),
          label: l10n.linkCardConfirm,
          isLoading: _isSaving,
          onPressed: link,
        ),
      ],
      child: LabeledField(
        label: l10n.linkCardLabel,
        child: AppSelect<String?>(
          key: const Key('linkCardField'),
          value: selected,
          items: [
            if (selected == null)
              AppSelectItem(value: null, label: l10n.linkCardPlaceholder),
            for (final card in cards)
              AppSelectItem(
                value: card.id,
                label: '${card.name} · ${card.institution}',
                leading: InstitutionAvatar(name: card.institution, size: 20),
              ),
          ],
          onChanged: (id) => setState(() => _cardId = id),
        ),
      ),
    );
  }
}
