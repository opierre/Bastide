import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';
import 'simulator_labels.dart';

/// A property price in thousands, as scenario names read it — « 320 k€ ».
String scenarioPriceLabel(AppLocalizations l10n, String locale, int minor) =>
    l10n.simulatorPriceThousands(
      NumberFormat.decimalPattern(locale).format(minor / 100000),
    );

/// The live row's name: its price once there is one.
String liveScenarioName(
  AppLocalizations l10n,
  String locale,
  SimulatorInputs inputs,
) => switch (inputs.propertyPriceMinor) {
  final price? when price > 0 => scenarioPriceLabel(l10n, locale, price),
  _ => l10n.simulatorLiveName,
};

/// « Scénarios enregistrés » (`14-simulateur.md` §Scenarios Card): the live
/// simulation first, marked « EN COURS », then the saved scenarios, each with a
/// checkbox toward the side-by-side comparison.
///
/// The live row counts toward the three like any other. At three the rest dim
/// and the list says how to free a slot; below two the compare control says
/// why it is off. Deleting a saved row is immediate — it is a scratchpad.
class ScenarioListCard extends ConsumerWidget {
  const ScenarioListCard({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(simulatorControllerProvider.notifier);
    final scenarios = state.scenarios;

    if (scenarios.isEmpty) {
      return AppCard(
        key: const Key('scenarioCard'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.simulatorScenariosTitle, style: textTheme.titleMedium),
            const Expanded(child: _MiniEmptyState()),
          ],
        ),
      );
    }

    final count = state.selection.length;
    final unchecked = [
      if (!state.isSelected(SimulatorState.liveId) && state.canCompute)
        liveScenarioName(l10n, locale, state.inputs),
      for (final scenario in scenarios)
        if (!state.isSelected(scenario.id)) scenario.label,
    ];
    final String? note;
    if (state.selectionFull && unchecked.isNotEmpty) {
      note = unchecked.length == 1
          ? l10n.simulatorCompareCapNamed(unchecked.single)
          : l10n.simulatorCompareCap;
    } else if (!state.canOpenComparison) {
      note = l10n.simulatorCompareNeedsTwo;
    } else {
      note = null;
    }

    return AppCard(
      key: const Key('scenarioCard'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.simulatorScenariosTitle,
                  style: textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  key: const Key('scenarioCompareButton'),
                  onPressed: state.canOpenComparison
                      ? controller.openComparison
                      : null,
                  style: count == 0
                      ? null
                      : OutlinedButton.styleFrom(
                          foregroundColor: AppColors.iris,
                          side: BorderSide(
                            color: AppColors.iris.withValues(alpha: 0.45),
                          ),
                        ),
                  child: Text(
                    l10n.simulatorCompareButton(
                      count,
                      SimulatorState.maxCompared,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (state.actionError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            InlineBanner(
              key: const Key('scenarioActionError'),
              message: localizeSimulatorError(l10n, state.actionError),
              onDismiss: controller.clearActionError,
              dismissTooltip: l10n.simulatorCancel,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              key: const Key('scenarioList'),
              padding: EdgeInsets.zero,
              children: [
                _ScenarioRow(
                  id: SimulatorState.liveId,
                  name: liveScenarioName(l10n, locale, state.inputs),
                  live: true,
                  subline: _subline(
                    l10n,
                    locale,
                    state.inputs.annualRateBps,
                    state.inputs.termMonths,
                    state.result?.totalInstalmentMinor,
                    state.household.currency,
                  ),
                  state: state,
                ),
                for (final scenario in scenarios)
                  _ScenarioRow(
                    id: scenario.id,
                    name: scenario.label,
                    subline: _subline(
                      l10n,
                      locale,
                      scenario.terms.annualRateBps,
                      scenario.terms.termMonths,
                      state.scenarioInstalments[scenario.id],
                      scenario.currency,
                    ),
                    state: state,
                    onDelete: () => controller.deleteScenario(scenario.id),
                  ),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              note,
              key: const Key('scenarioNote'),
              style: AppTextStyles.helper.copyWith(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _subline(
    AppLocalizations l10n,
    String locale,
    int? rateBps,
    int termMonths,
    int? instalmentMinor,
    String currency,
  ) {
    final rate = rateBps == null ? '—' : formatRate(rateBps, locale);
    final term = termLabel(l10n, termMonths);
    if (instalmentMinor == null) {
      return l10n.simulatorScenarioSubNoInstalment(rate, term);
    }
    return l10n.simulatorScenarioSub(
      rate,
      term,
      formatAmount(
        amountMinor: instalmentMinor,
        currency: currency,
        locale: locale,
      ),
    );
  }
}

class _ScenarioRow extends ConsumerWidget {
  const _ScenarioRow({
    required this.id,
    required this.name,
    required this.subline,
    required this.state,
    this.live = false,
    this.onDelete,
  });

  final String id;
  final String name;
  final String subline;
  final SimulatorState state;
  final bool live;

  /// `null` for the live row, which has nothing saved to delete.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = state.isSelected(id);
    final selectable = state.isSelectable(id);
    void toggle() =>
        ref.read(simulatorControllerProvider.notifier).toggleSelection(id);

    return Opacity(
      opacity: selectable ? 1 : 0.5,
      child: Container(
        key: Key('scenarioRow-$id'),
        height: 46,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: InkWell(
          onTap: selectable ? toggle : null,
          child: Row(
            children: [
              _Checkbox(
                key: Key('scenarioCheck-$id'),
                value: selected,
                enabled: selectable,
                semanticLabel: l10n.simulatorScenarioSelect(name),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            key: Key('scenarioName-$id'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (live) ...[
                          const SizedBox(width: AppSpacing.sm - 2),
                          SimulatorMarkerPill(
                            key: const Key('scenarioLivePill'),
                            label: l10n.simulatorLivePill,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subline,
                      key: Key('scenarioSub-$id'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tabularNumberStyle(
                        AppTextStyles.helper,
                      ).copyWith(fontSize: 11, color: AppColors.textDisabled),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<void>(
                  key: Key('scenarioMenu-$id'),
                  icon: const Icon(Icons.more_horiz_rounded, size: 18),
                  iconColor: AppColors.textSecondary,
                  tooltip: l10n.simulatorScenarioActions,
                  position: PopupMenuPosition.under,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      key: Key('scenarioDelete-$id'),
                      onTap: onDelete,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(l10n.simulatorScenarioDelete),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 18 px checkbox (radius 5): iris fill and an ink check when checked.
/// Material's [Checkbox] carries touch-sized padding the row has no room for.
class _Checkbox extends StatelessWidget {
  const _Checkbox({
    super.key,
    required this.value,
    required this.enabled,
    required this.semanticLabel,
  });

  final bool value;
  final bool enabled;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      enabled: enabled,
      label: semanticLabel,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: value ? AppColors.iris : AppColors.surfaceField,
          borderRadius: BorderRadius.circular(5),
          border: value ? null : Border.all(color: AppColors.borderDashed),
        ),
        child: value
            ? const Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.irisInk,
              )
            : null,
      ),
    );
  }
}

/// ⑤: the scenarios card with nothing saved — no compare control, one line on
/// what the card is for.
class _MiniEmptyState extends StatelessWidget {
  const _MiniEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      key: const Key('scenariosEmpty'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.irisSoft,
                borderRadius: BorderRadius.circular(AppRadii.inset),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 20,
                color: AppColors.iris,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(
              l10n.simulatorScenariosEmptyTitle,
              style: textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.simulatorScenariosEmptyBody,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSaveScenarioModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SaveScenarioModal(),
  );
}

/// The small « Enregistrer le scénario » modal: one name, prefilled on the
/// « lieu — prix k€ » pattern with the place left for the user to type in
/// front of the dash.
class SaveScenarioModal extends ConsumerStatefulWidget {
  const SaveScenarioModal({super.key});

  @override
  ConsumerState<SaveScenarioModal> createState() => _SaveScenarioModalState();
}

class _SaveScenarioModalState extends ConsumerState<SaveScenarioModal> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _filled = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final price = ref
        .read(simulatorControllerProvider)
        .value
        ?.inputs
        .propertyPriceMinor;
    if (price == null) return;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    _name.value = TextEditingValue(
      text: l10n.simulatorSaveNamePrefill(
        scenarioPriceLabel(l10n, locale, price),
      ),
      // The place goes first: the caret waits in front of the dash.
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(simulatorControllerProvider.notifier)
          .saveScenario(_name.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeSimulatorError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      title: l10n.simulatorSaveScenario,
      width: 440,
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.simulatorCancel),
        ),
        PrimaryButton(
          key: const Key('saveScenarioSubmit'),
          label: l10n.simulatorSaveSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.simulatorSaveBody,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorText != null) ...[
              InlineBanner(
                key: const Key('saveScenarioError'),
                message: _errorText!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.simulatorSaveName,
              child: TextFormField(
                key: const Key('saveScenarioName'),
                controller: _name,
                autofocus: true,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  return trimmed.isEmpty
                      ? l10n.simulatorSaveNameRequired
                      : null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
