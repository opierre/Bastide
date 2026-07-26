import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';

class ImportsScreen extends StatelessWidget {
  const ImportsScreen({super.key});

  static const path = '/imports';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      key: const Key('screen-imports'),
      icon: Icons.upload_file_outlined,
      accent: AppColors.irisDeep,
      title: l10n.comingSoonTitle,
      message: l10n.comingSoonBody,
    );
  }
}
