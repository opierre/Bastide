import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const path = '/settings';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('screen-settings'),
      child: Text(l10n.navSettings, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
