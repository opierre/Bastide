import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';

/// The Placements panel (`docs/design/17-placements.md`).
///
/// For now it is the panel's empty state only, so the sidebar item the shell
/// carries (#201) lands somewhere true. The list, the inspector and the
/// « Nouveau placement » button arrive with the panel itself (#218).
class PlacementsScreen extends StatelessWidget {
  const PlacementsScreen({super.key});

  static const path = '/investments';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      key: const Key('screen-placements'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: EmptyStateView(
        title: l10n.placementsEmptyTitle,
        message: l10n.placementsEmptyMessage,
      ),
    );
  }
}
