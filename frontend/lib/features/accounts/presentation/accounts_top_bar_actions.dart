import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import 'account_form.dart';

/// The accounts panel's contribution to the top bar: the primary add action.
///
/// It lives with the feature rather than in the shell so the panel owns its own
/// controls.
class AccountsTopBarActions extends StatelessWidget {
  const AccountsTopBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PrimaryButton(
      key: const Key('addAccountButton'),
      label: l10n.accountsAddButton,
      icon: Icons.add_rounded,
      onPressed: () => showAccountForm(context),
    );
  }
}
