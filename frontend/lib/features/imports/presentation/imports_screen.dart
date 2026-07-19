import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class ImportsScreen extends StatelessWidget {
  const ImportsScreen({super.key});

  static const path = '/imports';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('screen-imports'),
      child: Text(l10n.navImports, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
