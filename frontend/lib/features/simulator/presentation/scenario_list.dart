import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_checkbox.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/note_line.dart';
import '../../../l10n/app_localizations.dart';
import '../application/simulator_controller.dart';
import '../domain/simulation.dart';
import 'simulator_labels.dart';

/// A property price in thousands, as scenario names read it: « 320 k€ ».
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

/// « Scénarios enregistrés » (`14-simulateur.md` §Inputs pane, 6–7): the live
/// simulation first, its sub-line led by « en cours », then the saved
/// scenarios, each with a checkbox toward the comparison.
///
/// The live row counts toward the three like any other. At three the other
/// checkboxes are disabled and a note says how to free a slot. Deleting a
/// saved row is immediate: it is a scratchpad.
class ScenarioList extends ConsumerWidget {
  const ScenarioList({super.key, required this.state});

  final SimulatorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(simulatorControllerProvider.notifier);
    final scenarios = state.scenarios;

    final heading = Row(
      children: [
        Expanded(
          child: Text(
            l10n.simulatorScenariosTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
        ),
        if (scenarios.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.smPlus),
          AppButton(
            key: const Key('scenarioCompareButton'),
            label: l10n.simulatorCompareButton(
              state.selection.length,
              SimulatorState.maxCompared,
            ),
            onPressed: state.canOpenComparison
                ? controller.openComparison
                : null,
          ),
        ],
      ],
    );

    if (scenarios.isEmpty) {
      return Column(
        key: const Key('scenarioList'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: AppSpacing.fieldGap),
          NoteLine(
            key: const Key('scenariosEmpty'),
            text: l10n.simulatorScenariosEmpty,
          ),
        ],
      );
    }

    final unchecked = [
      if (!state.isSelected(SimulatorState.liveId) && state.canCompute)
        liveScenarioName(l10n, locale, state.inputs),
      for (final scenario in scenarios)
        if (!state.isSelected(scenario.id)) scenario.label,
    ];
    final note = !state.selectionFull || unchecked.isEmpty
        ? null
        : unchecked.length == 1
        ? l10n.simulatorCompareCapNamed(unchecked.single)
        : l10n.simulatorCompareCap;

    String sub(int? rateBps, int termMonths) => l10n.simulatorScenarioSub(
      rateBps == null ? l10n.simulatorNoValue : formatRate(rateBps, locale),
      termLabel(l10n, termMonths),
    );

    return Column(
      key: const Key('scenarioList'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
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
        _ScenarioRow(
          id: SimulatorState.liveId,
          name: liveScenarioName(l10n, locale, state.inputs),
          subline: l10n.simulatorScenarioSubLive(
            switch (state.inputs.annualRateBps) {
              final bps? => formatRate(bps, locale),
              null => l10n.simulatorNoValue,
            },
            termLabel(l10n, state.inputs.termMonths),
          ),
          instalmentMinor: state.result?.totalInstalmentMinor,
          currency: state.household.currency,
          state: state,
        ),
        for (final scenario in scenarios)
          _ScenarioRow(
            id: scenario.id,
            name: scenario.label,
            subline: sub(
              scenario.terms.annualRateBps,
              scenario.terms.termMonths,
            ),
            instalmentMinor: state.scenarioInstalments[scenario.id],
            currency: scenario.currency,
            state: state,
            onRename: () => showRenameScenarioModal(context, scenario),
            onDelete: () => controller.deleteScenario(scenario.id),
          ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.sm),
          NoteLine(key: const Key('scenarioNote'), text: note),
        ],
      ],
    );
  }
}

/// One scenario: checkbox · name over « taux · durée » · spacer · instalment
/// `textSecondary` · the `ellipsis` menu, shown on hover or focus.
class _ScenarioRow extends ConsumerStatefulWidget {
  const _ScenarioRow({
    required this.id,
    required this.name,
    required this.subline,
    required this.instalmentMinor,
    required this.currency,
    required this.state,
    this.onRename,
    this.onDelete,
  });

  final String id;
  final String name;
  final String subline;
  final int? instalmentMinor;
  final String currency;
  final SimulatorState state;

  /// `null` for the live row, which has nothing saved to rename or delete.
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_ScenarioRow> createState() => _ScenarioRowState();
}

class _ScenarioRowState extends ConsumerState<_ScenarioRow> {
  final _menu = MenuController();

  /// Hover and focus are row ephemera: they only reveal the menu.
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final id = widget.id;
    final state = widget.state;
    final selected = state.isSelected(id);
    final selectable = state.isSelectable(id);
    final instalment = widget.instalmentMinor;
    void toggle() =>
        ref.read(simulatorControllerProvider.notifier).toggleSelection(id);

    final hasMenu = widget.onRename != null || widget.onDelete != null;
    final showMenu = _hovered || _focused || _menu.isOpen;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selectable ? toggle : null,
          child: SizedBox(
            key: Key('scenarioRow-$id'),
            height: AppSizes.tableRowTwoLines,
            child: Row(
              children: [
                AppCheckbox(
                  key: Key('scenarioCheck-$id'),
                  value: selected,
                  onChanged: selectable ? (_) => toggle() : null,
                  semanticLabel: l10n.simulatorScenarioSelect(widget.name),
                ),
                const SizedBox(width: AppSpacing.smPlus),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        key: Key('scenarioName-$id'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                      Text(
                        widget.subline,
                        key: Key('scenarioSub-$id'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tabularNumberStyle(
                          textTheme.bodySmall!,
                        ).copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (instalment != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatAmount(
                      amountMinor: instalment,
                      currency: widget.currency,
                      locale: locale,
                    ),
                    key: Key('scenarioInstalment-$id'),
                    style: tabularNumberStyle(
                      textTheme.bodyMedium!,
                    ).copyWith(color: colors.textSecondary),
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
                // The menu keeps its place when hidden, so the instalments
                // stay aligned whether a row is hovered or not.
                SizedBox(
                  width: AppSizes.button,
                  child: hasMenu
                      ? Visibility(
                          visible: showMenu,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          maintainInteractivity: true,
                          child: MenuAnchor(
                            controller: _menu,
                            style: AppPopover.menuStyle(context),
                            alignmentOffset: const Offset(0, AppSpacing.xs),
                            onOpen: () => setState(() {}),
                            onClose: () => setState(() {}),
                            menuChildren: [
                              if (widget.onRename case final rename?)
                                AppMenuItem(
                                  key: Key('scenarioRename-$id'),
                                  label: l10n.simulatorScenarioRename,
                                  leading: const Icon(LucideIcons300.pencil),
                                  onPressed: rename,
                                ),
                              if (widget.onDelete case final delete?)
                                AppMenuItem(
                                  key: Key('scenarioDelete-$id'),
                                  label: l10n.simulatorScenarioDelete,
                                  leading: const Icon(LucideIcons300.trash2),
                                  destructive: true,
                                  onPressed: delete,
                                ),
                            ],
                            child: AppButton(
                              key: Key('scenarioMenu-$id'),
                              label: l10n.simulatorScenarioActions,
                              icon: LucideIcons300.ellipsis,
                              iconOnly: true,
                              variant: AppButtonVariant.ghost,
                              onPressed: () =>
                                  _menu.isOpen ? _menu.close() : _menu.open(),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showSaveScenarioModal(BuildContext context) {
  return showAppModal<void>(
    context: context,
    builder: (_) => const SaveScenarioModal(),
  );
}

Future<void> showRenameScenarioModal(
  BuildContext context,
  SavedSimulation scenario,
) {
  return showAppModal<void>(
    context: context,
    builder: (_) => SaveScenarioModal(renaming: scenario),
  );
}

/// « Enregistrer le scénario » (`proposal_v6` `m-simulator`): 420 px, no
/// lead, one « Nom » field, « Annuler » · ink « Enregistrer ». The name is
/// prefilled on the « lieu, prix k€ » pattern with the caret waiting in
/// front of the comma for the place. With [renaming] the same modal is
/// « Renommer le scénario », prefilled with the scenario's current name.
class SaveScenarioModal extends ConsumerStatefulWidget {
  const SaveScenarioModal({super.key, this.renaming});

  final SavedSimulation? renaming;

  @override
  ConsumerState<SaveScenarioModal> createState() => _SaveScenarioModalState();
}

class _SaveScenarioModalState extends ConsumerState<SaveScenarioModal> {
  final _name = TextEditingController();

  /// The prefilled name: the form is dirty once the field leaves it.
  String _initialName = '';
  bool _filled = false;
  bool _isSubmitting = false;
  bool _nameMissing = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    // Typing clears the field error; the dirty flag follows the text.
    setState(() {
      if (_name.text.trim().isNotEmpty) _nameMissing = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    if (widget.renaming case final scenario?) {
      _initialName = scenario.label;
      _name.value = TextEditingValue(
        text: scenario.label,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: scenario.label.length,
        ),
      );
      return;
    }
    final price = ref
        .read(simulatorControllerProvider)
        .value
        ?.inputs
        .propertyPriceMinor;
    if (price == null) return;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    _initialName = l10n.simulatorSaveNamePrefill(
      scenarioPriceLabel(l10n, locale, price),
    );
    _name.value = TextEditingValue(
      text: _initialName,
      // The place goes first: the caret waits in front of the comma.
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _saveError = null;
    });
    final controller = ref.read(simulatorControllerProvider.notifier);
    try {
      if (widget.renaming case final scenario?) {
        await controller.renameScenario(scenario.id, name);
      } else {
        await controller.saveScenario(name);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      // The input stays as it was; the frame shows the banner.
      setState(() {
        _isSubmitting = false;
        _saveError = localizeSimulatorError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameError = _nameMissing ? l10n.simulatorSaveNameRequired : null;

    return AppModal(
      key: const Key('saveScenarioModal'),
      title: widget.renaming == null
          ? l10n.simulatorSaveScenario
          : l10n.simulatorRenameTitle,
      width: AppModalSizes.w420,
      dirty: _name.text != _initialName,
      busy: _isSubmitting,
      saveError: _saveError,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('saveScenarioCancel')),
        AppButton(
          key: const Key('saveScenarioSubmit'),
          label: l10n.simulatorSaveSubmit,
          variant: AppButtonVariant.primary,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
      child: LabeledField(
        label: l10n.simulatorSaveName,
        errorText: nameError,
        child: TextField(
          key: const Key('saveScenarioName'),
          controller: _name,
          autofocus: true,
          decoration: nameError == null ? null : errorFieldDecoration(context),
        ),
      ),
    );
  }
}
