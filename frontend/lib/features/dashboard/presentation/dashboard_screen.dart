import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const path = '/dashboard';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('screen-dashboard'),
      child: Text(l10n.navDashboard, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
