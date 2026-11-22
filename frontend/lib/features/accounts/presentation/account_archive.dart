import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../domain/account.dart';
import 'account_error_localizer.dart';

/// Asks before archiving [account], then archives it. Resolves to whether it
/// was archived.
///
/// Archive, never delete: an account's transactions are history, and deleting
/// it would take them with it. Shared by the accounts list and the account
/// detail, so the question reads the same from either.
Future<bool> confirmArchiveAccount(
  BuildContext context,
  WidgetRef ref,
  Account account,
) async {
  final archived = await showAppModal<bool>(
    context: context,
    builder: (_) => AccountArchiveModal(account: account),
  );
  return archived ?? false;
}

/// « Archiver ce compte ? »: a reversible confirmation (`05-accounts.md`,
/// proposal v6 `m-accounts`), so the primary stays in ink and takes the
/// initial focus. A failed archive stays in the modal as its save error.
class AccountArchiveModal extends ConsumerStatefulWidget {
  const AccountArchiveModal({super.key, required this.account});

  final Account account;

  @override
  ConsumerState<AccountArchiveModal> createState() =>
      _AccountArchiveModalState();
}

class _AccountArchiveModalState extends ConsumerState<AccountArchiveModal> {
  bool _isArchiving = false;
  String? _errorText;

  Future<void> _archive() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isArchiving = true;
      _errorText = null;
    });
    try {
      await ref
          .read(accountsControllerProvider.notifier)
          .archive(widget.account.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = localizeAccountError(l10n, error));
    } finally {
      if (mounted) setState(() => _isArchiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppModal(
      key: const Key('accountArchiveModal'),
      width: AppModalSizes.w420,
      kind: AppModalKind.confirmation,
      title: l10n.accountArchiveConfirmTitle,
      subtitle: Text(l10n.accountArchiveConfirmBody),
      busy: _isArchiving,
      saveError: _errorText,
      actions: [
        const AppModalCancel(key: Key('accountArchiveCancelButton')),
        PrimaryButton(
          key: const Key('accountArchiveConfirmButton'),
          label: l10n.accountArchive,
          isLoading: _isArchiving,
          onPressed: _isArchiving ? null : _archive,
        ),
      ],
    );
  }
}
