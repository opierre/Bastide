import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const path = '/dashboard';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      key: const Key('screen-dashboard'),
      icon: Icons.insights_outlined,
      accent: AppColors.brandAccent,
      title: l10n.comingSoonTitle,
      message: l10n.comingSoonBody,
    );
  }
}
