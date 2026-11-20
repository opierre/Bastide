import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import 'scenario_compare.dart';
import 'scenario_list.dart';
import 'simulation_result.dart';
import 'simulator_form.dart';
import 'simulator_labels.dart';
import 'yearly_projection_chart.dart';

/// The Simulateur panel (`docs/design/14-simulateur.md`), flush: the inputs
/// pane on the left (380 px, right hairline) and the reading pane on the
/// right, on screen together so a keystroke's effect is seen where it lands.
/// The comparison replaces the reading pane while it is open.
///
/// No loan figure on it is computed in Dart: every amount, share and ratio is
/// the backend engine's.
class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({super.key});

  static const path = '/simulations';

  /// The inputs pane's width (`14` §Layout).
  static const inputsWidth = 380.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(simulatorControllerProvider);

    return KeyedSubtree(
      key: const Key('screen-simulator'),
      child: switch (state) {
        AsyncData(:final value) => _SimulatorPanel(state: value),
        AsyncError() => ErrorStateView(
          message: l10n.simulatorLoadFailed,
          messageKey: const Key('simulatorErrorText'),
          retryLabel: l10n.simulatorRetry,
          retryKey: const Key('simulatorRetryButton'),
          onRetry: () =>
              ref.read(simulatorControllerProvider.notifier).refresh(),
        ),
        _ => const _LoadingView(),
      },
    );
  }
}

/// The panel's contribution to the title bar: the secondary « Enregistrer le
/// scénario ». Off until the inputs make a loan with a price, never because
/// of what the HCSF reading says.
class SimulatorTopBarActions extends ConsumerWidget {
  const SimulatorTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSave = ref.watch(
      simulatorControllerProvider.select(
        (state) => state.value?.canSave ?? false,
      ),
    );

    return AppButton(
      key: const Key('simulatorSaveButton'),
      label: AppLocalizations.of(context)!.simulatorSaveScenario,
      icon: LucideIcons300.bookmark,
      onPressed: canSave ? () => showSaveScenarioModal(context) : null,
    );
  }
}

class _SimulatorPanel extends StatelessWidget {
  const _SimulatorPanel({required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('simulatorInputsPane'),
          width: SimulatorScreen.inputsWidth,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: context.colors.line)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SimulatorForm(state: state),
                const SizedBox(height: AppSpacing.fieldGap),
                Divider(height: 1, thickness: 1, color: context.colors.line),
                const SizedBox(height: AppSpacing.fieldGap),
                ScenarioList(state: state),
              ],
            ),
          ),
        ),
        Expanded(
          child: state.comparison != null
              ? ScenarioComparison(state: state)
              : _ReadingPane(state: state),
        ),
      ],
    );
  }
}

/// The reading pane, padding 24 32, blocks 22 apart with a hairline between
/// them: the summary line, the HCSF reading, the yearly projection.
class _ReadingPane extends StatelessWidget {
  const _ReadingPane({required this.state});

  final SimulatorState state;

  /// The blocks' spacing (`14` §Reading pane): 22 px, a hairline in the
  /// middle of each gap.
  static const _halfGap = 11.0;

  /// Below this height the pane scrolls and the chart keeps a fixed height.
  static const _minFlexibleHeight = 640.0;
  static const _fixedChartHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final computeError = state.computeError;
    // A refusal that belongs to a field is explained under that field; only
    // what no field explains reaches the banner.
    final bannerError =
        computeError != null &&
        simulatorErrorField(computeError) == SimulatorErrorField.none;

    Widget hairline() => Padding(
      padding: const EdgeInsets.symmetric(vertical: _halfGap),
      child: Divider(height: 1, thickness: 1, color: context.colors.line),
    );

    List<Widget> blocks(Widget chart) => [
      if (bannerError) ...[
        InlineBanner(
          key: const Key('simulatorComputeError'),
          message: l10n.simulatorComputeFailed,
        ),
        const SizedBox(height: _halfGap * 2),
      ],
      SimulationSummaryLine(state: state),
      hairline(),
      HcsfReading(state: state),
      hairline(),
      chart,
    ];

    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.lg,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= _minFlexibleHeight) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: blocks(
                Expanded(child: YearlyProjection(result: state.result)),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: blocks(
              SizedBox(
                height: _fixedChartHeight,
                child: YearlyProjection(result: state.result),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The panel's silhouette: the inputs pane's fields and rows on the left, the
/// summary line, the three readings and the chart on the right.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      key: const Key('simulatorLoading'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: SimulatorScreen.inputsWidth,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.colors.line)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonBlock(height: AppSizes.formField * 3 + 56),
                SizedBox(height: AppSpacing.fieldGap),
                SkeletonBlock(height: AppSizes.formField),
                SizedBox(height: AppSpacing.fieldGap),
                SkeletonBlock(height: AppSizes.tableRowTwoLines * 3),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonBlock(height: 96),
                  SizedBox(height: AppSpacing.lg),
                  SkeletonBlock(height: 120),
                  SizedBox(height: AppSpacing.lg),
                  Expanded(child: SkeletonBlock(height: double.infinity)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
