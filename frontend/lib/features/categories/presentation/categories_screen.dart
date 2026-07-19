import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const path = '/categories';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('screen-categories'),
      child: Text(l10n.navCategories, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
