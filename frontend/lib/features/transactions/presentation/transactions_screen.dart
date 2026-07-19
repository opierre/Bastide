import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  static const path = '/transactions';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('screen-transactions'),
      child: Text(l10n.navTransactions, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
