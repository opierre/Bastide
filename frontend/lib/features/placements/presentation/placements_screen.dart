import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import 'placement_form_modal.dart';
import 'placement_inspector.dart';
import 'placements_list_pane.dart';

/// The Placements panel (`docs/design/17-placements.md`): a flush panel of
/// two panes, the placements list and the inspector of the selected one.
class PlacementsScreen extends ConsumerWidget {
  const PlacementsScreen({super.key});

  static const path = '/investments';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(placementsControllerProvider);
    final selectedId = ref.watch(selectedPlacementProvider);

    const padded = EdgeInsets.symmetric(
      horizontal: AppSpacing.pageX,
      vertical: AppSpacing.pageY,
    );

    return KeyedSubtree(
      key: const Key('screen-placements'),
      child: switch (state) {
        AsyncData(:final value) when value.investments.isEmpty => Padding(
          padding: padded,
          child: EmptyStateView(
            key: const Key('placementsEmptyState'),
            title: l10n.placementsEmptyTitle,
            message: l10n.placementsEmptyMessage,
            action: PrimaryButton(
              key: const Key('placementsEmptyAddButton'),
              label: l10n.placementsAdd,
              icon: LucideIcons300.plus,
              onPressed: () => showPlacementForm(context),
            ),
          ),
        ),
        AsyncData(:final value) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PlacementsListPane(
                state: value,
                selected: value.selectedIn(selectedId),
              ),
            ),
            if (value.selectedIn(selectedId) case final investment?)
              PlacementInspector(investment: investment),
          ],
        ),
        AsyncError() => Padding(
          padding: padded,
          child: ErrorStateView(
            message: l10n.placementsLoadFailed,
            messageKey: const Key('placementsErrorText'),
            retryLabel: l10n.placementsRetry,
            retryKey: const Key('placementsRetryButton'),
            onRetry: () =>
                ref.read(placementsControllerProvider.notifier).refresh(),
          ),
        ),
        _ => const _PlacementsSkeleton(),
      },
    );
  }
}

/// The panel's contribution to the title bar: the primary « Nouveau
/// placement » (`plus`).
class PlacementsTopBarActions extends StatelessWidget {
  const PlacementsTopBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PrimaryButton(
      key: const Key('addPlacementButton'),
      label: l10n.placementsAdd,
      icon: LucideIcons300.plus,
      onPressed: () => showPlacementForm(context),
    );
  }
}

/// Loading: the silhouettes of both panes (`00` §7 States of a panel).
class _PlacementsSkeleton extends StatelessWidget {
  const _PlacementsSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SkeletonPulse(
      key: const Key('placementsLoadingIndicator'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageX,
                vertical: AppSpacing.pageY,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBlock(height: 12, width: 160),
                  const SizedBox(height: AppSpacing.xs),
                  const SkeletonBlock(height: 40, width: 280),
                  const SizedBox(height: AppPlacements.listGap),
                  for (var i = 0; i < 3; i++) ...[
                    const SkeletonBlock(height: AppSizes.tableRowTwoLines - 8),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          Container(
            width: AppSizes.inspector,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.rail,
              border: Border(left: BorderSide(color: colors.line)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(height: 32, width: 220),
                SizedBox(height: AppSpacing.md),
                SkeletonBlock(height: 28, width: 200),
                SizedBox(height: AppSpacing.md),
                SkeletonBlock(height: AppPlacements.chartHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
