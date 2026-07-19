import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  static const path = '/accounts';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('screen-accounts'),
      child: Text(l10n.navAccounts, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
