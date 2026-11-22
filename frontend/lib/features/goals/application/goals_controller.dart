import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/pictures/pictures.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';

/// Why a goal's banner image did not change, after the goal itself was saved.
///
/// Raised into [GoalsState.actionError] rather than to the form: the goal is
/// already written, so the form has nothing left to retry.
@immutable
class GoalImageError {
  const GoalImageError(this.failure);

  final PictureUploadFailure failure;
}

/// Maps a refused banner upload's error `code` to the shared failure kinds,
/// so it reads with the avatar's own wording.
PictureUploadFailure goalImageFailureOf(Object error) => switch (error) {
  ApiFailure(code: 'GOAL_IMAGE_TOO_LARGE') => PictureUploadFailure.tooLarge,
  ApiFailure(code: 'GOAL_IMAGE_INVALID_IMAGE') =>
    PictureUploadFailure.invalidType,
  _ => PictureUploadFailure.generic,
};

/// Everything the Objectifs panel renders in one value: the table's goals,
/// the archived ones behind the « N objectifs archivés » link, the savings balances the
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

  /// The table's goals — active and reached, never archived.
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

  /// The over-allocation banner is dismissible and never blocking, so a
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
  /// other accounts holds "savings", which is the same reason the API refuses
  /// to let this block anything.
  bool get isOverAllocated =>
      savingsAccounts.isNotEmpty && allocatedTotalMinor > savingsTotalMinor;

  /// How much more is reserved than the savings accounts hold; what the
  /// over-allocation banner states.
  int get overAllocationMinor => allocatedTotalMinor - savingsTotalMinor;

  /// The goal the inspector shows for a selection of [goalId]: that goal when
  /// it is on screen, else the first of the table (`11-goals.md` §Table: the
  /// first goal is selected on arrival). An archived goal counts only while
  /// the archived list is open.
  Goal? selectedIn(String? goalId) {
    final visible = [...goals, if (showArchived) ...archived];
    return visible.where((goal) => goal.id == goalId).firstOrNull ??
        visible.firstOrNull;
  }

  /// The currency every figure on this panel is in. The app is one currency per
  /// user, so the first thing carrying one answers for all of them.
  String get currency =>
      goals.firstOrNull?.currency ??
      archived.firstOrNull?.currency ??
      savingsAccounts.firstOrNull?.currency ??
      '';

  /// The dashboard's « Objectifs » rows: up to four active goals, by creation
  /// order (`docs/design/04-dashboard.md` §5b).
  /// Ties keep the API's order (`List.sort` is not stable on its own).
  List<Goal> get topGoals {
    final indexed = goals.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.createdAt.compareTo(b.$2.createdAt);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    return [for (final (_, goal) in indexed.take(4)) goal];
  }

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
/// `reached` are both derived from the allocation ledger server-side,
/// so a client that adjusted them locally would be
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
  ///
  /// [image] is the cropped banner PNG, uploaded once the goal exists. Its
  /// failure doesn't undo the goal: it lands in [GoalsState.actionError].
  /// The new goal becomes the selection.
  Future<Goal> create({
    required String name,
    required int targetMinor,
    DateTime? targetDate,
    Uint8List? image,
  }) async {
    final created = await _repository.create(
      name: name,
      targetMinor: targetMinor,
      targetDate: targetDate,
    );
    ref.read(selectedGoalProvider.notifier).select(created.id);
    final imageError = image == null
        ? null
        : await _imageChange(() => _repository.uploadImage(created.id, image));
    await _refreshReporting(imageError);
    return created;
  }

  /// Edits a goal's user-owned fields. Like [create], failures reach the form.
  ///
  /// Editing a target can move the goal across the reached boundary either way,
  /// which is settled server-side and arrives with the reload. [image]
  /// replaces the banner and [removeImage] drops it, as in [create].
  Future<Goal> updateGoal(
    String goalId, {
    String? name,
    int? targetMinor,
    DateTime? targetDate,
    Uint8List? image,
    bool removeImage = false,
  }) async {
    final updated = await _repository.update(
      goalId,
      name: name,
      targetMinor: targetMinor,
      targetDate: targetDate,
    );
    final imageError = image != null
        ? await _imageChange(() => _repository.uploadImage(goalId, image))
        : removeImage
        ? await _imageChange(() => _repository.removeImage(goalId))
        : null;
    await _refreshReporting(imageError);
    return updated;
  }

  /// Makes [png] the goal's banner image. Failures are rethrown: the crop
  /// modal is still open and shows them.
  Future<void> uploadImage(String goalId, Uint8List png) async {
    await _repository.uploadImage(goalId, png);
    await refresh();
  }

  /// Drops the goal's banner image; a failure lands in the panel's banner.
  Future<void> removeImage(String goalId) async {
    final error = await _imageChange(() => _repository.removeImage(goalId));
    await _refreshReporting(error);
  }

  /// Runs one image write, returning why it failed instead of throwing.
  Future<GoalImageError?> _imageChange(Future<void> Function() write) async {
    try {
      await write();
      return null;
    } catch (error) {
      return GoalImageError(goalImageFailureOf(error));
    }
  }

  /// Reloads, then reports [error] (if any) without blanking the panel.
  Future<void> _refreshReporting(Object? error) async {
    await refresh();
    final current = state.value;
    if (error != null && current != null) {
      state = AsyncValue.data(current.copyWith(actionError: error));
    }
  }

  /// Archives a goal: it leaves the table and the dashboard, keeps its
  /// allocation history, and can be restored from the archived list.
  Future<void> archive(String goalId) =>
      _write(() => _repository.update(goalId, status: GoalStatus.archived));

  /// Restores an archived goal. Whether it lands on active or reached is the
  /// backend's arithmetic over the ledger, not something this client claims.
  Future<void> restore(String goalId) =>
      _write(() => _repository.update(goalId, status: GoalStatus.active));

  /// Deletes a goal with its allocations and image. A failure lands in the
  /// panel's banner; the confirmation closes either way. The inspector falls
  /// back to the first goal of the table once the reload drops this one.
  Future<void> delete(String goalId) async {
    await _write(() => _repository.delete(goalId));
    ref.invalidate(goalAllocationsProvider(goalId));
  }

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

  /// Lists the archived goals under the table, or folds them away.
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

  /// Shows [error] in the panel's banner, for a failure raised outside a
  /// write (a picture file the picker refused).
  void reportError(Object error) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(actionError: error));
  }

  void clearActionError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(clearActionError: true));
  }

  /// Runs a write the panel — rather than a form — issued, keeping the table
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

/// The goal the user picked in the table, or `null` before they pick one.
///
/// Read through [GoalsState.selectedIn], which falls back to the first goal:
/// the inspector always shows something (`docs/design/11-goals.md`).
class SelectedGoal extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String goalId) => state = goalId;
}

final selectedGoalProvider = NotifierProvider<SelectedGoal, String?>(
  SelectedGoal.new,
);
