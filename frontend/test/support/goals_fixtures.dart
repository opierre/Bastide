import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/domain/goal.dart';
import 'package:bastide/features/goals/domain/goal_allocation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four goals of `docs/design/11-goals.md` frame ①, in the drawn order —
/// so a widget test asserting on amounts is asserting against the design.
List<Goal> specGoals() => [
  testGoal(
    id: 'g1',
    name: "Fonds d'urgence",
    targetMinor: 1000000,
    progressMinor: 640000,
  ),
  testGoal(
    id: 'g2',
    name: 'Apport immobilier',
    targetMinor: 3000000,
    progressMinor: 1280000,
    targetDate: DateTime(2028, 6, 30),
  ),
  testGoal(
    id: 'g3',
    name: 'Voyage Japon',
    targetMinor: 400000,
    progressMinor: 400000,
    targetDate: DateTime(2026, 6, 30),
    status: GoalStatus.reached,
  ),
  testGoal(
    id: 'g4',
    name: 'Nouvelle cuisine',
    targetMinor: 800000,
    progressMinor: 125000,
    targetDate: DateTime(2026, 12, 31),
  ),
];

/// One goal. [progressPct] is derived the way the backend derives it, so a
/// fixture can't quietly disagree with the ratio it reports.
Goal testGoal({
  String id = 'g1',
  String name = "Fonds d'urgence",
  int targetMinor = 1000000,
  int progressMinor = 640000,
  String currency = 'EUR',
  DateTime? targetDate,
  String icon = 'flag',
  String color = '#8B8CF9',
  GoalStatus status = GoalStatus.active,
}) => Goal(
  id: id,
  name: name,
  targetMinor: targetMinor,
  currency: currency,
  targetDate: targetDate,
  icon: icon,
  color: color,
  status: status,
  progressMinor: progressMinor,
  progressPct: progressMinor / targetMinor,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 5, 1),
);

GoalAllocation testAllocation({
  String id = 'al1',
  String goalId = 'g1',
  int amountMinor = 30000,
  DateTime? allocatedOn,
  String? note = 'Virement mensuel',
}) => GoalAllocation(
  id: id,
  goalId: goalId,
  amountMinor: amountMinor,
  allocatedOn: allocatedOn ?? DateTime(2026, 5, 1),
  note: note,
  createdAt: DateTime(2026, 5, 1),
);

SavingsAccount testSavingsAccount({
  String id = 'a1',
  int balanceMinor = 2210000,
  String currency = 'EUR',
}) => SavingsAccount(id: id, balanceMinor: balanceMinor, currency: currency);

/// A no-network [GoalsController] double for widget tests: a fixed set of
/// goals, and a record of the writes the panel attempted.
class FakeGoalsController extends GoalsController {
  FakeGoalsController({
    this.initialGoals = const [],
    this.archivedGoals = const [],
    this.savingsAccounts = const [],
    this.loadError,
  });

  final List<Goal> initialGoals;
  final List<Goal> archivedGoals;
  final List<SavingsAccount> savingsAccounts;
  final Object? loadError;

  final allocateCalls = <(String, int, DateTime, String?)>[];
  final archiveCalls = <String>[];
  final restoreCalls = <String>[];
  final deleteAllocationCalls = <(String, String)>[];
  Object? errorOnAllocate;

  @override
  Future<GoalsState> build() async {
    if (loadError != null) throw loadError!;
    return GoalsState(
      goals: initialGoals,
      archived: archivedGoals,
      savingsAccounts: savingsAccounts,
    );
  }

  @override
  Future<GoalAllocation> allocate(
    String goalId, {
    required int amountMinor,
    required DateTime allocatedOn,
    String? note,
  }) async {
    if (errorOnAllocate != null) throw errorOnAllocate!;
    allocateCalls.add((goalId, amountMinor, allocatedOn, note));
    return testAllocation(
      goalId: goalId,
      amountMinor: amountMinor,
      allocatedOn: allocatedOn,
      note: note,
    );
  }

  @override
  Future<void> archive(String goalId) async {
    archiveCalls.add(goalId);
    final current = state.value;
    if (current == null) return;
    final goal = current.goals
        .where((candidate) => candidate.id == goalId)
        .firstOrNull;
    if (goal == null) return;
    state = AsyncValue.data(
      current.copyWith(
        goals: [
          for (final candidate in current.goals)
            if (candidate.id != goalId) candidate,
        ],
        archived: [
          ...current.archived,
          testGoal(
            id: goal.id,
            name: goal.name,
            targetMinor: goal.targetMinor,
            progressMinor: goal.progressMinor,
            targetDate: goal.targetDate,
            status: GoalStatus.archived,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> restore(String goalId) async {
    restoreCalls.add(goalId);
  }

  @override
  Future<void> deleteAllocation(String goalId, String allocationId) async {
    deleteAllocationCalls.add((goalId, allocationId));
  }
}
