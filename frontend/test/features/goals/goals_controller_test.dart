import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/goals/application/goals_controller.dart';
import 'package:finstride/features/goals/domain/goal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _goalJson({
  String id = 'g1',
  String name = "Fonds d'urgence",
  int targetMinor = 1000000,
  int progressMinor = 640000,
  String status = 'active',
  String? targetDate,
}) => {
  'id': id,
  'name': name,
  'target_minor': targetMinor,
  'currency': 'EUR',
  'target_date': targetDate,
  'icon': 'flag',
  'color': '#8B8CF9',
  'status': status,
  'progress_minor': progressMinor,
  'progress_pct': progressMinor / targetMinor,
  'created_at': '2026-01-01T00:00:00',
  'updated_at': '2026-05-01T00:00:00',
};

Map<String, dynamic> _allocationJson({
  String id = 'al1',
  int amountMinor = 30000,
  String? note = 'Virement mensuel',
}) => {
  'id': id,
  'goal_id': 'g1',
  'amount_minor': amountMinor,
  'allocated_on': '2026-05-01',
  'note': note,
  'created_at': '2026-05-01T00:00:00',
};

Map<String, dynamic> _accountJson({
  String id = 'a1',
  String type = 'savings',
  int balanceMinor = 2210000,
  bool archived = false,
}) => {
  'id': id,
  'name': 'Livret A',
  'type': type,
  'institution': 'BNP',
  'currency': 'EUR',
  'ofx_account_id': null,
  'opening_balance_minor': 0,
  'balance_minor': balanceMinor,
  'archived': archived,
  'created_at': '2026-01-01T00:00:00',
  'updated_at': '2026-05-01T00:00:00',
};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  /// Stubs the three calls one load makes. The goals list and the archived list
  /// hit the same path under different queries, so they are stubbed by query.
  void stubLoad({
    List<Map<String, dynamic>>? goals,
    List<Map<String, dynamic>>? archived,
    List<Map<String, dynamic>>? accounts,
  }) {
    when(
      () => apiClient.get('/goals', query: {}),
    ).thenAnswer((_) async => goals ?? [_goalJson()]);
    when(
      () => apiClient.get('/goals', query: {'status': 'archived'}),
    ).thenAnswer((_) async => archived ?? <Map<String, dynamic>>[]);
    when(
      () => apiClient.get('/accounts'),
    ).thenAnswer((_) async => accounts ?? [_accountJson()]);
  }

  test(
    'build loads the grid, the archived goals and the savings balances',
    () async {
      stubLoad(
        goals: [
          _goalJson(),
          _goalJson(id: 'g2', name: 'Voyage Japon'),
        ],
        archived: [
          _goalJson(id: 'g9', name: 'Vieux projet', status: 'archived'),
        ],
      );

      final state = await container.read(goalsControllerProvider.future);

      expect(state.goals, hasLength(2));
      expect(state.goals.first.name, "Fonds d'urgence");
      expect(state.goals.first.progressMinor, 640000);
      expect(state.goals.first.progressPct, closeTo(0.64, 1e-9));
      // The count the « Afficher les objectifs archivés (N) » link states is on
      // screen before the list is, so it has to be loaded up front.
      expect(state.archived, hasLength(1));
      expect(state.savingsTotalMinor, 2210000);
    },
  );

  test('a goal is created and the panel reloads behind it', () async {
    stubLoad();
    when(() => apiClient.post('/goals', body: any(named: 'body'))).thenAnswer(
      (_) async => _goalJson(id: 'g2', name: 'Voyage Japon', progressMinor: 0),
    );
    await container.read(goalsControllerProvider.future);

    final created = await container
        .read(goalsControllerProvider.notifier)
        .create(
          name: 'Voyage Japon',
          targetMinor: 400000,
          icon: 'travel',
          color: '#4FD1E8',
          targetDate: DateTime(2026, 6, 30),
        );

    expect(created.name, 'Voyage Japon');
    verify(
      () => apiClient.post(
        '/goals',
        body: {
          'name': 'Voyage Japon',
          'target_minor': 400000,
          'target_date': '2026-06-30',
          'icon': 'travel',
          'color': '#4FD1E8',
        },
      ),
    ).called(1);
  });

  test('a positive allocation raises the goal progress', () async {
    stubLoad();
    when(
      () => apiClient.post('/goals/g1/allocations', body: any(named: 'body')),
    ).thenAnswer((_) async => _allocationJson());
    await container.read(goalsControllerProvider.future);

    // The reload behind the write is what moves progress: the sum is the
    // backend's, and a client that added the line to its own copy would be
    // answering a question it doesn't own.
    stubLoad(goals: [_goalJson(progressMinor: 670000)]);
    await container
        .read(goalsControllerProvider.notifier)
        .allocate('g1', amountMinor: 30000, allocatedOn: DateTime(2026, 5, 14));

    final state = container.read(goalsControllerProvider).value!;
    expect(state.goals.single.progressMinor, 670000);
    verify(
      () => apiClient.post(
        '/goals/g1/allocations',
        body: {'amount_minor': 30000, 'allocated_on': '2026-05-14'},
      ),
    ).called(1);
  });

  test(
    'a negative allocation goes through the same flow and lowers progress',
    () async {
      stubLoad();
      when(
        () => apiClient.post('/goals/g1/allocations', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => _allocationJson(id: 'al2', amountMinor: -15000),
      );
      await container.read(goalsControllerProvider.future);

      stubLoad(goals: [_goalJson(progressMinor: 625000)]);
      await container
          .read(goalsControllerProvider.notifier)
          .allocate(
            'g1',
            amountMinor: -15000,
            allocatedOn: DateTime(2026, 3, 12),
            note: 'Réparation voiture',
          );

      expect(
        container
            .read(goalsControllerProvider)
            .value!
            .goals
            .single
            .progressMinor,
        625000,
      );
      // One endpoint, one signed field — there is no withdrawal call to reach for.
      verify(
        () => apiClient.post(
          '/goals/g1/allocations',
          body: {
            'amount_minor': -15000,
            'allocated_on': '2026-03-12',
            'note': 'Réparation voiture',
          },
        ),
      ).called(1);
    },
  );

  test(
    'deleting an allocation recomputes progress and the reached status',
    () async {
      stubLoad(goals: [_goalJson(progressMinor: 1000000, status: 'reached')]);
      when(
        () => apiClient.delete('/goals/g1/allocations/al1'),
      ).thenAnswer((_) async => null);
      await container.read(goalsControllerProvider.future);
      expect(
        container.read(goalsControllerProvider).value!.goals.single.isReached,
        isTrue,
      );

      stubLoad(goals: [_goalJson(progressMinor: 700000)]);
      await container
          .read(goalsControllerProvider.notifier)
          .deleteAllocation('g1', 'al1');

      final goal = container.read(goalsControllerProvider).value!.goals.single;
      expect(goal.progressMinor, 700000);
      expect(goal.status, GoalStatus.active);
      verify(() => apiClient.delete('/goals/g1/allocations/al1')).called(1);
    },
  );

  test(
    'archiving moves the goal out of the grid and into the archived list',
    () async {
      stubLoad();
      when(
        () => apiClient.patch('/goals/g1', body: any(named: 'body')),
      ).thenAnswer((_) async => _goalJson(status: 'archived'));
      await container.read(goalsControllerProvider.future);

      stubLoad(
        goals: [],
        archived: [_goalJson(status: 'archived')],
      );
      await container.read(goalsControllerProvider.notifier).archive('g1');

      final state = container.read(goalsControllerProvider).value!;
      expect(state.goals, isEmpty);
      expect(state.archived, hasLength(1));
      verify(
        () => apiClient.patch('/goals/g1', body: {'status': 'archived'}),
      ).called(1);
    },
  );

  test(
    'restoring brings the goal back, on whatever status the ledger implies',
    () async {
      stubLoad(
        goals: [],
        archived: [_goalJson(status: 'archived')],
      );
      when(
        () => apiClient.patch('/goals/g1', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => _goalJson(progressMinor: 1000000, status: 'reached'),
      );
      await container.read(goalsControllerProvider.future);

      stubLoad(
        goals: [_goalJson(progressMinor: 1000000, status: 'reached')],
        archived: [],
      );
      await container.read(goalsControllerProvider.notifier).restore('g1');

      final state = container.read(goalsControllerProvider).value!;
      expect(state.archived, isEmpty);
      // The client asks for `active`; the backend answers `reached` from the sum.
      expect(state.goals.single.status, GoalStatus.reached);
      verify(
        () => apiClient.patch('/goals/g1', body: {'status': 'active'}),
      ).called(1);
    },
  );

  test('a refused write keeps the grid standing and reports itself', () async {
    stubLoad();
    when(
      () => apiClient.patch('/goals/g1', body: any(named: 'body')),
    ).thenThrow(
      const ApiFailure(code: 'GOAL_NOT_FOUND', message: 'Goal not found.'),
    );
    await container.read(goalsControllerProvider.future);

    await container.read(goalsControllerProvider.notifier).archive('g1');

    final state = container.read(goalsControllerProvider).value!;
    expect(state.goals, hasLength(1));
    expect((state.actionError! as ApiFailure).code, 'GOAL_NOT_FOUND');
  });

  test(
    'over-allocation is the allocated total against the savings balances',
    () async {
      stubLoad(
        goals: [
          _goalJson(progressMinor: 1500000),
          _goalJson(id: 'g2', progressMinor: 945000),
        ],
        accounts: [_accountJson(balanceMinor: 2210000)],
      );

      final state = await container.read(goalsControllerProvider.future);

      expect(state.allocatedTotalMinor, 2445000);
      expect(state.savingsTotalMinor, 2210000);
      expect(state.isOverAllocated, isTrue);
    },
  );

  test(
    'archived goals and non-savings accounts stay out of the comparison',
    () async {
      stubLoad(
        goals: [_goalJson(progressMinor: 500000)],
        archived: [
          _goalJson(id: 'g9', progressMinor: 900000, status: 'archived'),
        ],
        accounts: [
          _accountJson(balanceMinor: 600000),
          // A current account is not savings, and an archived savings account is
          // not money the user is holding — neither counts.
          _accountJson(id: 'a2', type: 'checking', balanceMinor: 5000000),
          _accountJson(id: 'a3', balanceMinor: 5000000, archived: true),
        ],
      );

      final state = await container.read(goalsControllerProvider.future);

      expect(state.allocatedTotalMinor, 500000);
      expect(state.savingsTotalMinor, 600000);
      expect(state.isOverAllocated, isFalse);
    },
  );

  test('with no savings account there is nothing to warn against', () async {
    stubLoad(goals: [_goalJson(progressMinor: 500000)], accounts: []);

    final state = await container.read(goalsControllerProvider.future);

    // The app has no basis for deciding which of the user's other accounts is
    // "savings", which is the same reason §13 refuses to let this block.
    expect(state.isOverAllocated, isFalse);
  });

  test(
    'the reveal and the dismissal survive the reload a write triggers',
    () async {
      stubLoad(
        archived: [_goalJson(id: 'g9', status: 'archived')],
      );
      when(
        () => apiClient.patch('/goals/g1', body: any(named: 'body')),
      ).thenAnswer((_) async => _goalJson(status: 'archived'));
      await container.read(goalsControllerProvider.future);

      final controller = container.read(goalsControllerProvider.notifier);
      controller.toggleArchived();
      controller.dismissOverAllocationBanner();
      await controller.archive('g1');

      final state = container.read(goalsControllerProvider).value!;
      expect(state.showArchived, isTrue);
      expect(state.bannerDismissed, isTrue);
    },
  );

  test('the panel reports only the top three goals to the dashboard', () async {
    stubLoad(
      goals: [
        _goalJson(id: 'g1'),
        _goalJson(id: 'g2'),
        _goalJson(id: 'g3'),
        _goalJson(id: 'g4'),
      ],
    );

    final state = await container.read(goalsControllerProvider.future);

    expect(state.topGoals.map((goal) => goal.id), ['g1', 'g2', 'g3']);
  });
}
