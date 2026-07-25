import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const path = '/settings';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      key: const Key('screen-settings'),
      icon: Icons.tune_rounded,
      accent: AppColors.textSecondary,
      title: l10n.comingSoonTitle,
      message: l10n.comingSoonBody,
    );
  }
}
