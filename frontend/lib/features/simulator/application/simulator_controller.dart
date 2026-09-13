import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/simulations_repository.dart';
import '../domain/simulation.dart';
import '../domain/simulation_result.dart';

/// One column of the side-by-side comparison: a scenario's terms and the
/// engine's figures for them, with the ratio read both without and with the
/// existing loans.
@immutable
class ComparisonColumn {
  const ComparisonColumn({
    required this.id,
    required this.label,
    required this.terms,
    required this.result,
    required this.ratioWithExistingBps,
  });

  /// [SimulatorState.liveId] for the unsaved simulation.
  final String id;

  /// `null` for the live simulation, which has no name yet.
  final String? label;
  final SimulationTerms terms;
  final SimulationResult result;
  final int? ratioWithExistingBps;

  bool get isLive => id == SimulatorState.liveId;
}

/// Everything the Simulateur panel renders.
///
/// [result] is `null` whenever there is nothing to compute — the empty state —
/// or when the last compute was refused ([computeError]). The live result is
/// never stored anywhere: it is the answer to the inputs on screen.
@immutable
class SimulatorState {
  const SimulatorState({
    required this.inputs,
    required this.household,
    required this.scenarios,
    this.principalDerived = true,
    this.scenarioInstalments = const {},
    this.result,
    this.computeError,
    this.computing = false,
    this.selection = const [],
    this.comparison,
    this.actionError,
  });

  /// The id the live, unsaved simulation takes in the scenario list.
  static const liveId = 'live';

  /// Side by side stops being readable beyond this (§17).
  static const maxCompared = 3;

  final SimulatorInputs inputs;

  /// Whether the borrowed amount is still the price + fees − down payment
  /// default. Editing the amount turns it off until the price or the down
  /// payment changes again.
  final bool principalDerived;
  final HouseholdContext household;
  final List<SavedSimulation> scenarios;

  /// Each saved scenario's instalment for its list sub-line, keyed by id.
  final Map<String, int> scenarioInstalments;
  final SimulationResult? result;
  final Object? computeError;
  final bool computing;

  /// Checked rows, in the order they were checked.
  final List<String> selection;

  /// `null` while the comparison is closed.
  final AsyncValue<List<ComparisonColumn>>? comparison;

  /// A refused delete, shown without replacing the panel.
  final Object? actionError;

  bool get canCompute => inputs.terms != null;

  /// A scenario needs a price on top of a computable loan, and a loan the
  /// engine refused cannot be saved. An over-reference reading never blocks it.
  bool get canSave {
    final price = inputs.propertyPriceMinor;
    return canCompute && price != null && price > 0 && computeError == null;
  }

  /// The ratio can only be read with a known income.
  bool get incomeKnown => result?.debtRatioBps != null;

  bool isSelected(String id) => selection.contains(id);

  bool get selectionFull => selection.length >= maxCompared;

  /// A checked row can always be unchecked; an unchecked one only while a slot
  /// is free — and the live row only once it has something to compare.
  bool isSelectable(String id) {
    if (isSelected(id)) return true;
    if (selectionFull) return false;
    return id != liveId || canCompute;
  }

  /// One column is not a comparison.
  bool get canOpenComparison => selection.length >= 2;

  static const _unset = Object();

  SimulatorState copyWith({
    SimulatorInputs? inputs,
    bool? principalDerived,
    HouseholdContext? household,
    List<SavedSimulation>? scenarios,
    Map<String, int>? scenarioInstalments,
    Object? result = _unset,
    Object? computeError = _unset,
    bool? computing,
    List<String>? selection,
    Object? comparison = _unset,
    Object? actionError = _unset,
  }) => SimulatorState(
    inputs: inputs ?? this.inputs,
    principalDerived: principalDerived ?? this.principalDerived,
    household: household ?? this.household,
    scenarios: scenarios ?? this.scenarios,
    scenarioInstalments: scenarioInstalments ?? this.scenarioInstalments,
    result: identical(result, _unset)
        ? this.result
        : result as SimulationResult?,
    computeError: identical(computeError, _unset)
        ? this.computeError
        : computeError,
    computing: computing ?? this.computing,
    selection: selection ?? this.selection,
    comparison: identical(comparison, _unset)
        ? this.comparison
        : comparison as AsyncValue<List<ComparisonColumn>>?,
    actionError: identical(actionError, _unset)
        ? this.actionError
        : actionError,
  );
}

/// The Simulateur panel's state: the form's inputs, the live result, the saved
/// scenarios and the comparison.
///
/// The result is fed by a debounced `POST /simulations/compute` and never by a
/// formula written here (§17: one engine). The only arithmetic this class does
/// is the borrowed amount's default, a convenience the user can overwrite.
class SimulatorController extends AsyncNotifier<SimulatorState> {
  /// Long enough to let a figure be typed out, short enough to feel live.
  static const debounce = Duration(milliseconds: 350);

  SimulationsRepository get _repository =>
      ref.read(simulationsRepositoryProvider);

  Timer? _timer;

  /// Bumped by every input change, so a slow answer to older inputs can never
  /// overwrite a newer one.
  int _generation = 0;

  @override
  Future<SimulatorState> build() async {
    ref.onDispose(() => _timer?.cancel());
    final household = await _repository.household();
    final scenarios = await _repository.list();
    unawaited(_loadInstalments(scenarios));
    return SimulatorState(
      inputs: const SimulatorInputs(),
      household: household,
      scenarios: scenarios,
    );
  }

  Future<void> refresh() async {
    _timer?.cancel();
    _generation++;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  void setPropertyPrice(int? minor) => _edit(
    (inputs) => inputs.copyWith(propertyPriceMinor: minor),
    resumeDerivation: true,
  );

  void setDownPayment(int? minor) => _edit(
    (inputs) => inputs.copyWith(downPaymentMinor: minor),
    resumeDerivation: true,
  );

  void setFees(int? minor) =>
      _edit((inputs) => inputs.copyWith(upfrontFeesMinor: minor));

  /// The user's own borrowed amount: derivation stops here.
  void setPrincipal(int? minor) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        inputs: current.inputs.copyWith(principalMinor: minor),
        principalDerived: false,
      ),
    );
    _schedule();
  }

  void setRate(int? bps) =>
      _edit((inputs) => inputs.copyWith(annualRateBps: bps));

  void setInsurance(int? minor) =>
      _edit((inputs) => inputs.copyWith(insuranceMonthlyMinor: minor));

  void setTerm(int months) =>
      _edit((inputs) => inputs.copyWith(termMonths: months));

  /// Changes only the ratio side of the reading; the result row is the same
  /// loan either way.
  void setIncludeExistingLoans(bool include) =>
      _edit((inputs) => inputs.copyWith(includeExistingLoans: include));

  void _edit(
    SimulatorInputs Function(SimulatorInputs) change, {
    bool resumeDerivation = false,
  }) {
    final current = state.value;
    if (current == null) return;
    final derived = current.principalDerived || resumeDerivation;
    var inputs = change(current.inputs);
    if (derived) {
      inputs = inputs.copyWith(principalMinor: _defaultPrincipal(inputs));
    }
    state = AsyncValue.data(
      current.copyWith(inputs: inputs, principalDerived: derived),
    );
    _schedule();
  }

  /// Price + fees − down payment: what is left to borrow. `null` without a
  /// price, or when the down payment covers everything.
  static int? _defaultPrincipal(SimulatorInputs inputs) {
    final price = inputs.propertyPriceMinor;
    if (price == null) return null;
    final principal =
        price + (inputs.upfrontFeesMinor ?? 0) - (inputs.downPaymentMinor ?? 0);
    return principal > 0 ? principal : null;
  }

  void _schedule() {
    _timer?.cancel();
    final generation = ++_generation;
    final current = state.value;
    if (current == null) return;
    if (!current.canCompute) {
      state = AsyncValue.data(
        current.copyWith(result: null, computeError: null, computing: false),
      );
      unawaited(_refreshComparisonIfLive());
      return;
    }
    state = AsyncValue.data(current.copyWith(computing: true));
    _timer = Timer(debounce, () => _compute(generation));
  }

  Future<void> _compute(int generation) async {
    final current = state.value;
    final terms = current?.inputs.terms;
    if (current == null || terms == null) return;
    try {
      final result = await _repository.compute(
        terms,
        includeExistingLoans: current.inputs.includeExistingLoans,
      );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncValue.data(
        state.value!.copyWith(
          result: result,
          computeError: null,
          computing: false,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncValue.data(
        state.value!.copyWith(
          result: null,
          computeError: error,
          computing: false,
        ),
      );
    }
    await _refreshComparisonIfLive();
  }

  /// Saves the current inputs under [label]. Rethrown: the naming modal is
  /// still open and explains the refusal.
  Future<SavedSimulation> saveScenario(String label) async {
    final current = state.value;
    final terms = current?.inputs.terms;
    if (current == null || terms == null || !current.canSave) {
      throw StateError('Nothing to save.');
    }
    final saved = await _repository.create(label, terms);
    final latest = state.value ?? current;
    state = AsyncValue.data(
      latest.copyWith(scenarios: [...latest.scenarios, saved]),
    );
    unawaited(_loadInstalments([saved]));
    return saved;
  }

  /// Hard-deletes a saved scenario — no confirmation for a scratchpad row.
  Future<void> deleteScenario(String simulationId) async {
    try {
      await _repository.delete(simulationId);
    } catch (error) {
      final current = state.value;
      if (current == null || !ref.mounted) return;
      state = AsyncValue.data(current.copyWith(actionError: error));
      return;
    }
    final current = state.value;
    if (current == null || !ref.mounted) return;
    final selection = [
      for (final id in current.selection)
        if (id != simulationId) id,
    ];
    state = AsyncValue.data(
      current.copyWith(
        scenarios: [
          for (final scenario in current.scenarios)
            if (scenario.id != simulationId) scenario,
        ],
        scenarioInstalments: {...current.scenarioInstalments}
          ..remove(simulationId),
        selection: selection,
        comparison: selection.length < 2 ? null : current.comparison,
        actionError: null,
      ),
    );
    if (selection.length >= 2) await _refreshComparison();
  }

  /// Checks or unchecks a row. A fourth check is ignored rather than
  /// replacing one: the list says how to free a slot instead.
  Future<void> toggleSelection(String id) async {
    final current = state.value;
    if (current == null) return;
    if (current.isSelected(id)) {
      final selection = [
        for (final selected in current.selection)
          if (selected != id) selected,
      ];
      state = AsyncValue.data(
        current.copyWith(
          selection: selection,
          comparison: selection.length < 2 ? null : current.comparison,
        ),
      );
    } else {
      if (!current.isSelectable(id)) return;
      state = AsyncValue.data(
        current.copyWith(selection: [...current.selection, id]),
      );
    }
    await _refreshComparison();
  }

  Future<void> openComparison() async {
    final current = state.value;
    if (current == null || !current.canOpenComparison) return;
    state = AsyncValue.data(
      current.copyWith(
        comparison: const AsyncValue<List<ComparisonColumn>>.loading(),
      ),
    );
    await _refreshComparison();
  }

  void closeComparison() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(comparison: null));
  }

  /// Declares the income the ratio runs on, then re-reads the household and
  /// recomputes. Rethrown to the modal that asked for it.
  Future<void> declareIncome(int monthlyIncomeMinor) async {
    await _repository.declareIncome(monthlyIncomeMinor);
    final household = await _repository.household();
    final current = state.value;
    if (current == null || !ref.mounted) return;
    state = AsyncValue.data(current.copyWith(household: household));
    _schedule();
    await _refreshComparison();
  }

  void clearActionError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(actionError: null));
  }

  Future<void> _refreshComparisonIfLive() async {
    if (state.value?.isSelected(SimulatorState.liveId) ?? false) {
      await _refreshComparison();
    }
  }

  /// Recomputes every open column — the live one follows the form, and saved
  /// ones are never stored with their figures.
  Future<void> _refreshComparison() async {
    final current = state.value;
    if (current == null || current.comparison == null) return;
    if (!current.canOpenComparison) {
      state = AsyncValue.data(current.copyWith(comparison: null));
      return;
    }

    final columns = <(String, String?, SimulationTerms)>[
      if (current.isSelected(SimulatorState.liveId))
        if (current.inputs.terms case final terms?)
          (SimulatorState.liveId, null, terms),
      for (final scenario in current.scenarios)
        if (current.isSelected(scenario.id))
          (scenario.id, scenario.label, scenario.terms),
    ];

    final comparison = await AsyncValue.guard(() async {
      final built = <ComparisonColumn>[];
      for (final (id, label, terms) in columns) {
        final base = await _repository.compute(
          terms,
          includeExistingLoans: false,
        );
        final withExisting = await _repository.compute(
          terms,
          includeExistingLoans: true,
        );
        built.add(
          ComparisonColumn(
            id: id,
            label: label,
            terms: terms,
            result: base,
            ratioWithExistingBps: withExisting.debtRatioBps,
          ),
        );
      }
      return built;
    });

    final latest = state.value;
    if (!ref.mounted || latest == null || latest.comparison == null) return;
    state = AsyncValue.data(latest.copyWith(comparison: comparison));
  }

  /// Fills each saved scenario's instalment for its list row. A scenario whose
  /// compute fails simply shows no instalment.
  Future<void> _loadInstalments(List<SavedSimulation> scenarios) async {
    final instalments = <String, int>{};
    for (final scenario in scenarios) {
      try {
        final result = await _repository.compute(
          scenario.terms,
          includeExistingLoans: false,
        );
        instalments[scenario.id] = result.totalInstalmentMinor;
      } catch (_) {
        // Left out: the row prints its rate and term alone.
      }
      if (!ref.mounted) return;
    }
    final current = state.value;
    if (current == null || instalments.isEmpty) return;
    state = AsyncValue.data(
      current.copyWith(
        scenarioInstalments: {...current.scenarioInstalments, ...instalments},
      ),
    );
  }
}

final simulatorControllerProvider =
    AsyncNotifierProvider<SimulatorController, SimulatorState>(
      SimulatorController.new,
    );
