import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const path = '/categories';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      key: const Key('screen-categories'),
      icon: Icons.donut_small_outlined,
      accent: AppColors.warning,
      title: l10n.comingSoonTitle,
      message: l10n.comingSoonBody,
    );
  }
}
