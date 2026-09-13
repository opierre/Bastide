import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import 'simulation_result.dart';
import 'simulator_form.dart';
import 'simulator_labels.dart';
import 'yearly_projection_chart.dart';

/// The Simulateur panel (`docs/design/14-simulateur.md`): the inputs on the
/// left, the live result, the HCSF reading and the yearly projection on the
/// right — on screen together, so a keystroke's effect is seen where it lands.
///
/// No loan figure on it is computed in Dart — every amount, share and ratio is
/// the backend engine's (`PROJECT.md` §17).
class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({super.key});

  static const path = '/simulations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(simulatorControllerProvider);

    return Padding(
      key: const Key('screen-simulator'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
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

/// The panel's contribution to the top bar.
class SimulatorTopBarActions extends StatelessWidget {
  const SimulatorTopBarActions({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Grid `400px minmax(0,1fr)`, gap 18 (`14-simulateur.md` §Layout).
class _SimulatorPanel extends StatelessWidget {
  const _SimulatorPanel({required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final computeError = state.computeError;
    // A refusal that belongs to a field is explained under that field; only
    // what no field explains reaches the banner.
    final bannerError =
        computeError != null &&
        simulatorErrorField(computeError) == SimulatorErrorField.none;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [SimulatorForm(state: state)],
          ),
        ),
        const SizedBox(width: AppSpacing.gridGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bannerError) ...[
                InlineBanner(
                  key: const Key('simulatorComputeError'),
                  message: l10n.simulatorComputeFailed,
                ),
                const SizedBox(height: AppSpacing.gridGap),
              ],
              SimulationResultRow(state: state),
              const SizedBox(height: AppSpacing.gridGap),
              HcsfReadingCard(state: state),
              const SizedBox(height: AppSpacing.gridGap),
              Expanded(child: YearlyProjectionCard(result: state.result)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The panel's silhouettes: the form and scenarios on the left, the result
/// row, the HCSF card and the chart on the right.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      key: Key('simulatorLoading'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonBlock(height: 440),
                SizedBox(height: AppSpacing.gridGap),
                Expanded(child: SkeletonBlock(height: double.infinity)),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.gridGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonBlock(height: 130),
                SizedBox(height: AppSpacing.gridGap),
                SkeletonBlock(height: 170),
                SizedBox(height: AppSpacing.gridGap),
                Expanded(child: SkeletonBlock(height: double.infinity)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
