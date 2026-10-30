import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../domain/account.dart';
import 'account_error_localizer.dart';

/// Asks before archiving [account], then archives it. Resolves to whether it
/// was archived; a failure is shown as a snackbar and resolves to `false`.
///
/// Archive, never delete: an account's transactions are history, and deleting
/// it would take them with it. Shared by the accounts list and the account
/// detail, so the question reads the same from either.
Future<bool> confirmArchiveAccount(
  BuildContext context,
  WidgetRef ref,
  Account account,
) async {
  final l10n = AppLocalizations.of(context)!;
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
  if (confirmed != true) return false;

  try {
    await ref.read(accountsControllerProvider.notifier).archive(account.id);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeAccountError(l10n, error))),
      );
    }
    return false;
  }
}
