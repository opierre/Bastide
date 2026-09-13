import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../../properties/application/properties_controller.dart';
import '../../properties/presentation/property_form_modal.dart';
import '../../properties/presentation/property_list.dart';
import '../application/networth_controller.dart';
import '../domain/networth_summary.dart';
import 'composition_breakdown.dart';
import 'networth_series_chart.dart';
import 'networth_summary_card.dart';

/// The Synthèse panel (`docs/design/15-synthese.md`): what the user owns
/// against what they owe, and the property list — declared here, because this
/// is where a user thinks about what they own.
///
/// Two controllers, one panel: the read-only net-worth summary and the
/// properties CRUD. No figure on it is computed in Dart (`PROJECT.md` §18).
class NetworthScreen extends ConsumerWidget {
  const NetworthScreen({super.key});

  static const path = '/networth';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summary = ref.watch(networthControllerProvider);
    final properties = ref.watch(propertiesControllerProvider);

    final Widget body;
    if ((summary.hasError && !summary.isLoading) ||
        (properties.hasError && !properties.isLoading)) {
      body = ErrorStateView(
        message: l10n.networthLoadFailed,
        messageKey: const Key('networthErrorText'),
        retryLabel: l10n.networthRetry,
        retryKey: const Key('networthRetryButton'),
        onRetry: () {
          ref.read(networthControllerProvider.notifier).refresh();
          ref.read(propertiesControllerProvider.notifier).refresh();
        },
      );
    } else if (summary.hasValue && properties.hasValue) {
      // `hasValue` rather than `AsyncData`: a property write invalidates the
      // summary, and the panel keeps the previous figures on screen while the
      // new ones are read instead of flashing its skeleton.
      final value = summary.requireValue;
      final list = properties.requireValue;
      body = value.isEmpty && list.properties.isEmpty && list.archived.isEmpty
          ? _EmptyState(currency: value.currency)
          : _Panel(summary: value, properties: list);
    } else {
      body = const _LoadingView();
    }

    return Padding(
      key: const Key('screen-networth'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: body,
    );
  }
}

/// The panel's contribution to the top bar: the secondary « Nouveau bien ».
class NetworthTopBarActions extends ConsumerWidget {
  const NetworthTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(
      networthControllerProvider.select((state) => state.value?.currency),
    );

    return SizedBox(
      height: AppChrome.controlPillHeight,
      child: OutlinedButton(
        key: const Key('addPropertyButton'),
        onPressed: () => showPropertyForm(context, currency: currency ?? ''),
        child: Text(AppLocalizations.of(context)!.networthAddProperty),
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.summary, required this.properties});

  final NetWorthSummary summary;
  final PropertiesState properties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final view = ref.watch(networthViewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 300,
              child: AppSegmented<NetworthView>(
                key: const Key('networthViewSwitch'),
                value: view,
                onChanged: ref.read(networthViewProvider.notifier).set,
                segments: [
                  AppSegment(
                    key: const Key('networthSummarySegment'),
                    value: NetworthView.summary,
                    label: l10n.networthViewSummary,
                  ),
                  AppSegment(
                    key: const Key('networthPropertiesSegment'),
                    value: NetworthView.properties,
                    // The count follows reality — « Biens (0) » included.
                    label: l10n.networthViewProperties(
                      properties.properties.length,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: switch (view) {
            NetworthView.summary => _SummaryView(
              summary: summary,
              properties: properties,
            ),
            NetworthView.properties => PropertyList(
              state: properties,
              currency: summary.currency,
            ),
          },
        ),
      ],
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary, required this.properties});

  final NetWorthSummary summary;
  final PropertiesState properties;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.gridGap);

    return CustomScrollView(
      key: const Key('networthSummaryView'),
      slivers: [
        SliverToBoxAdapter(child: NetworthSummaryRow(summary: summary)),
        const SliverToBoxAdapter(child: gap),
        // Row 2 fills the middle of the frame and keeps a readable minimum
        // when the window is short.
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 280),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // `minmax(0,1fr) minmax(0,1.5fr)`, gap 18.
                      Expanded(
                        flex: 100,
                        child: CompositionBreakdownCard(
                          summary: summary,
                          properties: properties.properties,
                          onNewProperty: () => showPropertyForm(
                            context,
                            currency: summary.currency,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.gridGap),
                      Expanded(
                        flex: 150,
                        child: NetworthSeriesCard(summary: summary),
                      ),
                    ],
                  ),
                ),
              ),
              gap,
              const NetworthExclusionsCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Frame ⑤: nothing to add up. The one state that drops the segmented control —
/// there is nothing to switch between.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return CenteredStatePane(
      key: const Key('networthEmptyState'),
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.irisSoft,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const SizedBox.square(
              dimension: 27,
              child: FittedBox(
                child: NavGlyphIcon(
                  glyph: NavGlyph.pie,
                  filled: false,
                  color: AppColors.iris,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.networthEmptyTitle,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            l10n.networthEmptyBody,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm + AppSpacing.xs,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  key: const Key('networthEmptyImport'),
                  onPressed: () => context.go(ImportsScreen.path),
                  child: Text(l10n.networthEmptyImport),
                ),
              ),
              PrimaryButton(
                key: const Key('networthEmptyAddProperty'),
                label: l10n.networthAddProperty,
                icon: Icons.add_rounded,
                height: 44,
                onPressed: () => showPropertyForm(context, currency: currency),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The panel's silhouettes: segmented control, the three figures, row 2, and
/// the exclusions strip.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      key: Key('networthLoading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBlock(height: 40, width: 300, radius: AppRadii.md),
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 150,
                  child: SkeletonBlock(height: double.infinity),
                ),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  flex: 100,
                  child: SkeletonBlock(height: double.infinity),
                ),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  flex: 100,
                  child: SkeletonBlock(height: double.infinity),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.gridGap),
          Expanded(child: SkeletonBlock(height: double.infinity)),
          SizedBox(height: AppSpacing.gridGap),
          SkeletonBlock(height: 90),
        ],
      ),
    );
  }
}
