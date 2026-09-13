import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';

/// The `yyyy-MM-dd` the API takes for a date-only field — the same wire format
/// the transactions repository sends, so a date means one shape on the wire
/// whichever feature wrote it.
final _isoDate = DateFormat('yyyy-MM-dd');

/// Calls the `/goals` endpoints and maps the wire JSON to domain models. The
/// only place in this feature that knows the response shapes.
///
/// It also reads `/accounts`, for the savings total the over-allocation banner
/// compares against. That is a foreign resource but the affordance is *this*
/// panel's, so the call stays here rather than reaching into another feature's
/// controller — the same arrangement the recurring repository uses for its
/// account picker. Only the narrow [SavingsAccount] shape is mapped: a balance
/// is all the banner needs.
class GoalsRepository {
  GoalsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Lists goals. Omitting [status] returns the active *and* reached ones —
  /// the grid's contents — and archived goals only come back when asked for
  /// by name, which is what the « Afficher les objectifs archivés » link does.
  Future<List<Goal>> list({GoalStatus? status}) async {
    final json =
        await _apiClient.get(
              '/goals',
              query: {if (status != null) 'status': status.wireValue},
            )
            as List<dynamic>;
    return json
        .map((entry) => _parseGoal(entry as Map<String, dynamic>))
        .toList();
  }

  Future<Goal> create({
    required String name,
    required int targetMinor,
    required String icon,
    required String color,
    DateTime? targetDate,
  }) async {
    final json =
        await _apiClient.post(
              '/goals',
              body: {
                'name': name,
                'target_minor': targetMinor,
                'target_date': ?_isoOrNull(targetDate),
                'icon': icon,
                'color': color,
              },
            )
            as Map<String, dynamic>;
    return _parseGoal(json);
  }

  /// Patches a goal, including archiving and restoring it through [status].
  ///
  /// Omitted fields are left alone — `null` is indistinguishable from absent on
  /// this API, so clearing a target date is not expressible and the form does
  /// not offer it.
  Future<Goal> update(
    String goalId, {
    String? name,
    int? targetMinor,
    DateTime? targetDate,
    String? icon,
    String? color,
    GoalStatus? status,
  }) async {
    final json =
        await _apiClient.patch(
              '/goals/$goalId',
              body: {
                'name': ?name,
                'target_minor': ?targetMinor,
                'target_date': ?_isoOrNull(targetDate),
                'icon': ?icon,
                'color': ?color,
                if (status != null) 'status': status.wireValue,
              },
            )
            as Map<String, dynamic>;
    return _parseGoal(json);
  }

  /// One goal's allocation history, newest first.
  Future<List<GoalAllocation>> listAllocations(String goalId) async {
    final json =
        await _apiClient.get('/goals/$goalId/allocations') as List<dynamic>;
    return json
        .map((entry) => _parseAllocation(entry as Map<String, dynamic>))
        .toList();
  }

  /// Appends one signed line. A negative [amountMinor] takes money back out of
  /// the envelope; there is no separate withdrawal call.
  Future<GoalAllocation> createAllocation(
    String goalId, {
    required int amountMinor,
    required DateTime allocatedOn,
    String? note,
  }) async {
    final json =
        await _apiClient.post(
              '/goals/$goalId/allocations',
              body: {
                'amount_minor': amountMinor,
                'allocated_on': _isoDate.format(allocatedOn),
                'note': ?note,
              },
            )
            as Map<String, dynamic>;
    return _parseAllocation(json);
  }

  Future<void> deleteAllocation(String goalId, String allocationId) =>
      _apiClient.delete('/goals/$goalId/allocations/$allocationId');

  /// The user's live savings accounts, for the over-allocation total.
  ///
  /// Archived accounts are left out: their balance is no longer money the user
  /// is holding anywhere, so counting it would understate the over-allocation
  /// the banner exists to report.
  Future<List<SavingsAccount>> listSavingsAccounts() async {
    final json = await _apiClient.get('/accounts') as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>())
        if (entry['type'] == 'savings' && entry['archived'] == false)
          SavingsAccount(
            id: entry['id'] as String,
            balanceMinor: entry['balance_minor'] as int,
            currency: entry['currency'] as String,
          ),
    ];
  }

  String? _isoOrNull(DateTime? date) =>
      date == null ? null : _isoDate.format(date);

  Goal _parseGoal(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetMinor: json['target_minor'] as int,
    currency: json['currency'] as String,
    targetDate: json['target_date'] == null
        ? null
        : DateTime.parse(json['target_date'] as String),
    icon: json['icon'] as String,
    color: json['color'] as String,
    status: GoalStatus.fromWire(json['status'] as String),
    progressMinor: json['progress_minor'] as int,
    progressPct: (json['progress_pct'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  GoalAllocation _parseAllocation(Map<String, dynamic> json) => GoalAllocation(
    id: json['id'] as String,
    goalId: json['goal_id'] as String,
    amountMinor: json['amount_minor'] as int,
    allocatedOn: DateTime.parse(json['allocated_on'] as String),
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref.watch(apiClientProvider));
});
