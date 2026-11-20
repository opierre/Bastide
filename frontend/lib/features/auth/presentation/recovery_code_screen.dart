import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'recovery_code_plate.dart';

/// Shows a newly issued recovery code, after registration or a password
/// reset, once and in the login column (`02-login.md`, Behaviour).
///
/// The router holds a signed-in user here while a code is pending, and only
/// « J’ai noté ce code » releases them: the backend keeps just a hash, so a
/// code scrolled past is a code lost.
class RecoveryCodeScreen extends ConsumerWidget {
  const RecoveryCodeScreen({super.key});

  static const path = '/recovery-code';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final code = ref.watch(pendingRecoveryCodeProvider);

    return AuthScaffold(
      children: [
        // Null only for the frame in which the router is already leaving.
        if (code != null) RecoveryCodePlate(code: code),
        Text(
          l10n.authRecoveryCodeKeep,
          key: const Key('recoveryCodeKeepNote'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        PrimaryButton.submit(
          key: const Key('recoveryCodeContinueButton'),
          label: l10n.authRecoveryCodeAcknowledge,
          onPressed: () =>
              ref.read(pendingRecoveryCodeProvider.notifier).acknowledge(),
        ),
      ],
    );
  }
}
