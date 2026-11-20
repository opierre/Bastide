import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../../properties/application/properties_controller.dart';
import '../../properties/presentation/property_form_modal.dart';
import '../application/networth_controller.dart';
import '../domain/networth_summary.dart';
import 'composition_breakdown.dart';
import 'networth_equation.dart';
import 'networth_notes.dart';
import 'networth_properties.dart';
import 'networth_series_chart.dart';

/// The Synthèse panel (`docs/design/15-synthese.md`): what the user owns
/// against what they owe, on one page of five blocks 24 px apart: the
/// equation line, composition and series, then properties and notes.
///
/// Two controllers, one panel: the read-only net-worth summary and the
/// properties CRUD. No figure on it is computed in Dart.
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
      // new ones are read instead of flashing its silhouette.
      final value = summary.requireValue;
      final list = properties.requireValue;
      body = value.isEmpty && list.properties.isEmpty && list.archived.isEmpty
          ? _EmptyState(currency: value.currency)
          : _Page(summary: value, properties: list);
    } else {
      body = const _LoadingView();
    }

    return Padding(
      key: const Key('screen-networth'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: body,
    );
  }
}

/// The panel's contribution to the title bar: the secondary « Nouveau bien ».
class NetworthTopBarActions extends ConsumerWidget {
  const NetworthTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(
      networthControllerProvider.select((state) => state.value?.currency),
    );

    return AppButton(
      key: const Key('addPropertyButton'),
      label: AppLocalizations.of(context)!.networthAddProperty,
      icon: LucideIcons300.plus,
      onPressed: () => showPropertyForm(context, currency: currency ?? ''),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.summary, required this.properties});

  final NetWorthSummary summary;
  final PropertiesState properties;

  @override
  Widget build(BuildContext context) {
    const section = SizedBox(height: AppSpacing.section);

    return SingleChildScrollView(
      key: const Key('networthPage'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NetworthEquation(summary: summary),
          section,
          const _Hairline(),
          section,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppNetworth.compositionWidth,
                child: CompositionSection(
                  summary: summary,
                  properties: properties.properties,
                ),
              ),
              const SizedBox(width: AppNetworth.compositionGutter),
              Expanded(child: NetworthSeriesSection(summary: summary)),
            ],
          ),
          section,
          const _Hairline(),
          section,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NetworthProperties(
                  state: properties,
                  currency: summary.currency,
                ),
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(child: NetworthNotes(summary: summary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The `line` hairline between two blocks (`00` §1.2).
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.colors.line);
}

/// Nothing to add up: no account, property, loan or investment.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return EmptyStateView(
      key: const Key('networthEmptyState'),
      title: l10n.networthEmptyTitle,
      message: l10n.networthEmptyBody,
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          PrimaryButton(
            key: const Key('networthEmptyAddProperty'),
            label: l10n.networthAddProperty,
            icon: LucideIcons300.plus,
            onPressed: () => showPropertyForm(context, currency: currency),
          ),
          AppButton(
            key: const Key('networthEmptyImport'),
            label: l10n.networthEmptyImport,
            onPressed: () => context.go(ImportsScreen.path),
          ),
        ],
      ),
    );
  }
}

/// The page's silhouette (`00` §7): the equation line, the two columns of
/// block 3, then the two of block 5, in `hover` blocks.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    const section = SizedBox(height: AppSpacing.section * 2 + 1);

    return const SkeletonPulse(
      key: Key('networthLoading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBlock(height: 72, width: 240),
              SizedBox(width: AppNetworth.equationGap),
              SkeletonBlock(height: 72, width: 200),
              SizedBox(width: AppNetworth.equationGap),
              SkeletonBlock(height: 84, width: 300),
            ],
          ),
          section,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppNetworth.compositionWidth,
                child: SkeletonBlock(height: 200),
              ),
              SizedBox(width: AppNetworth.compositionGutter),
              Expanded(child: SkeletonBlock(height: AppNetworth.chartHeight)),
            ],
          ),
          section,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SkeletonBlock(height: 120)),
              SizedBox(width: AppSpacing.gutter),
              Expanded(child: SkeletonBlock(height: 120)),
            ],
          ),
        ],
      ),
    );
  }
}
