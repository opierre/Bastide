import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';

/// Everything the Objectifs panel renders in one value: the grid's goals, the
/// archived ones behind the reveal link, the savings balances the
/// over-allocation banner is derived from, and the last action that failed.
///
/// [actionError] lives *inside* the data rather than turning the whole
/// `AsyncValue` into an error: a refused write says nothing about the goals the
/// user is looking at, and blanking the grid to report one failed click would
/// lose more than it explained.
@immutable
class GoalsState {
  const GoalsState({
    required this.goals,
    required this.archived,
    required this.savingsAccounts,
    this.showArchived = false,
    this.bannerDismissed = false,
    this.actionError,
  });

  /// The grid's goals — active and reached, never archived.
  final List<Goal> goals;

  /// The archived ones, loaded up front so the reveal link can state how many
  /// there are. The count is on screen before the list is, so it cannot wait
  /// for the click that opens it.
  final List<Goal> archived;

  /// The user's live savings accounts. Held rather than summed on load so the
  /// difference between "no savings account" and "savings accounts totalling
  /// zero" survives into [isOverAllocated].
  final List<SavingsAccount> savingsAccounts;

  final bool showArchived;

  /// The over-allocation banner is dismissible and never blocking (§13), so a
  /// dismissal is panel state rather than a stored preference.
  final bool bannerDismissed;

  final Object? actionError;

  /// What the user has set aside across every goal still in play.
  ///
  /// Archived goals are excluded: their allocations are history the user has
  /// deliberately put away, and counting them would keep warning about money
  /// committed to something already closed.
  int get allocatedTotalMinor =>
      goals.fold(0, (total, goal) => total + goal.progressMinor);

  int get savingsTotalMinor =>
      savingsAccounts.fold(0, (total, account) => total + account.balanceMinor);

  /// Whether the paper allocation runs past the money actually held in savings.
  ///
  /// Requires at least one savings account. With none there is nothing to
  /// compare against — the app is not entitled to decide which of a user's
  /// other accounts holds "savings", which is the same reason §13 refuses to
  /// let this block anything.
  bool get isOverAllocated =>
      savingsAccounts.isNotEmpty && allocatedTotalMinor > savingsTotalMinor;

  /// The currency every figure on this panel is in. The app is one currency per
  /// user, so the first thing carrying one answers for all of them.
  String get currency =>
      goals.firstOrNull?.currency ??
      archived.firstOrNull?.currency ??
      savingsAccounts.firstOrNull?.currency ??
      '';

  /// The dashboard card's rows: the first three goals of the grid, in the order
  /// the API returns them.
  List<Goal> get topGoals => goals.take(3).toList();

  GoalsState copyWith({
    List<Goal>? goals,
    List<Goal>? archived,
    List<SavingsAccount>? savingsAccounts,
    bool? showArchived,
    bool? bannerDismissed,
    Object? actionError,
    bool clearActionError = false,
  }) => GoalsState(
    goals: goals ?? this.goals,
    archived: archived ?? this.archived,
    savingsAccounts: savingsAccounts ?? this.savingsAccounts,
    showArchived: showArchived ?? this.showArchived,
    bannerDismissed: bannerDismissed ?? this.bannerDismissed,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );
}

/// The Objectifs panel's state: the goals, their archived siblings, and the
/// savings balances behind the over-allocation warning, loaded together.
///
/// Every write reloads rather than patching a row in place. Progress and
/// `reached` are both derived from the allocation ledger server-side
/// (`PROJECT.md` §13), so a client that adjusted them locally would be
/// answering a question the backend owns — and would get the reached moment,
/// the one this whole panel is built around, wrong at exactly the boundary.
class GoalsController extends AsyncNotifier<GoalsState> {
  GoalsRepository get _repository => ref.read(goalsRepositoryProvider);

  @override
  Future<GoalsState> build() => _load();

  Future<GoalsState> _load() async {
    final goals = await _repository.list();
    final archived = await _repository.list(status: GoalStatus.archived);
    final savingsAccounts = await _repository.listSavingsAccounts();
    return GoalsState(
      goals: goals,
      archived: archived,
      savingsAccounts: savingsAccounts,
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final loaded = await _load();
      // The reveal and the dismissal are things the user did to this panel, not
      // facts about the data — a reload behind an archive or an allocation must
      // not fold the archived list back up under them.
      return loaded.copyWith(
        showArchived: current?.showArchived ?? false,
        bannerDismissed: current?.bannerDismissed ?? false,
      );
    });
  }

  /// Creates a goal. Failures are rethrown: the form is still open and shows
  /// them inline, where the user can fix them.
  Future<Goal> create({
    required String name,
    required int targetMinor,
    required String icon,
    required String color,
    DateTime? targetDate,
  }) async {
    final created = await _repository.create(
      name: name,
      targetMinor: targetMinor,
      icon: icon,
      color: color,
      targetDate: targetDate,
    );
    await refresh();
    return created;
  }

  /// Edits a goal's user-owned fields. Like [create], failures reach the form.
  ///
  /// Editing a target can move the goal across the reached boundary either way,
  /// which is settled server-side and arrives with the reload.
  Future<Goal> updateGoal(
    String goalId, {
    String? name,
    int? targetMinor,
    DateTime? targetDate,
    String? icon,
    String? color,
  }) async {
    final updated = await _repository.update(
      goalId,
      name: name,
      targetMinor: targetMinor,
      targetDate: targetDate,
      icon: icon,
      color: color,
    );
    await refresh();
    return updated;
  }

  /// Archives a goal: it leaves the grid and the dashboard card, keeps its
  /// allocation history, and can be restored from the archived list.
  Future<void> archive(String goalId) =>
      _write(() => _repository.update(goalId, status: GoalStatus.archived));

  /// Restores an archived goal. Whether it lands on active or reached is the
  /// backend's arithmetic over the ledger, not something this client claims.
  Future<void> restore(String goalId) =>
      _write(() => _repository.update(goalId, status: GoalStatus.active));

  /// Appends one signed ledger line — positive puts money aside, negative takes
  /// it back out. One flow, because there is one mechanism.
  Future<GoalAllocation> allocate(
    String goalId, {
    required int amountMinor,
    required DateTime allocatedOn,
    String? note,
  }) async {
    final allocation = await _repository.createAllocation(
      goalId,
      amountMinor: amountMinor,
      allocatedOn: allocatedOn,
      note: note,
    );
    ref.invalidate(goalAllocationsProvider(goalId));
    await refresh();
    return allocation;
  }

  /// Removes a mistyped line. Progress — and with it the reached status — is
  /// recomputed by the reload that follows.
  Future<void> deleteAllocation(String goalId, String allocationId) async {
    await _write(() => _repository.deleteAllocation(goalId, allocationId));
    ref.invalidate(goalAllocationsProvider(goalId));
  }

  /// Folds the archived goals into the grid, or back away.
  void toggleArchived() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(showArchived: !current.showArchived),
    );
  }

  void dismissOverAllocationBanner() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(bannerDismissed: true));
  }

  void clearActionError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(clearActionError: true));
  }

  /// Runs a write the panel — rather than a form — issued, keeping the grid
  /// standing when the server refuses it.
  Future<void> _write(Future<void> Function() write) async {
    final current = state.value;
    if (current == null) return;
    try {
      await write();
      await refresh();
    } on ApiFailure catch (failure) {
      state = AsyncValue.data(current.copyWith(actionError: failure));
    }
  }
}

final goalsControllerProvider =
    AsyncNotifierProvider<GoalsController, GoalsState>(GoalsController.new);

/// One goal's allocation history, newest first. Invalidated by the controller
/// whenever a line is added or removed.
final goalAllocationsProvider =
    FutureProvider.family<List<GoalAllocation>, String>((ref, goalId) {
      return ref.watch(goalsRepositoryProvider).listAllocations(goalId);
    });

/// Which goal the panel is showing in detail, or `null` for the grid.
///
/// Panel state rather than a route: the detail is a *state of this panel* —
/// same chrome, same top-bar controls, an iris back link instead of a browser
/// step (`docs/design/11-goals.md` frame ②).
class SelectedGoal extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String goalId) => state = goalId;

  void close() => state = null;
}

final selectedGoalProvider = NotifierProvider<SelectedGoal, String?>(
  SelectedGoal.new,
);
