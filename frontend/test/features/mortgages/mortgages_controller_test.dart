import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/mortgages/application/mortgages_controller.dart';
import 'package:bastide/features/mortgages/domain/mortgage.dart';
import 'package:bastide/features/mortgages/domain/schedule_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/mortgages_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _mortgageJson({
  String id = 'm1',
  String label = 'Appartement Lyon 3e',
  String kind = 'mortgage',
  String status = 'active',
  String? nextPaymentOn = '2026-06-01',
}) => {
  'id': id,
  'label': label,
  'lender': 'BNP',
  'property_id': null,
  'kind': kind,
  'repayment_type': 'constant_payment',
  'principal_minor': 24000000,
  'annual_rate_bps': 345,
  'insurance_monthly_minor': 2880,
  'term_months': 300,
  'first_payment_date': '2023-09-01',
  'upfront_fees_minor': 145000,
  'status': status,
  'currency': 'EUR',
  'monthly_payment_minor': 119507,
  'total_instalment_minor': 122387,
  'outstanding_principal_minor': 22254270,
  'paid_principal_pct': 727,
  'remaining_months': 267,
  'next_payment_on': nextPaymentOn,
  'created_at': '2023-08-01T00:00:00',
  'updated_at': '2026-05-01T00:00:00',
};

Map<String, dynamic> _detailJson({
  String id = 'm1',
  String status = 'active',
}) => {
  ..._mortgageJson(id: id, status: status),
  'total_interest_minor': 11852100,
  'total_insurance_minor': 864000,
  'total_cost_minor': 12861100,
  'taeg_bps': 379,
  'last_payment_on': '2048-08-01',
};

Map<String, dynamic> _summaryJson({
  int? debtRatioBps = 3274,
  int? monthlyIncomeMinor = 460000,
  String incomeSource = 'declared',
  bool overLimit = false,
  int activeCount = 1,
}) => {
  'monthly_charge_minor': 150625,
  'total_outstanding_minor': 23412921,
  'total_principal_minor': 25500000,
  'repaid_principal_minor': 2087079,
  'repaid_pct_bps': 818,
  'next_payment_on': '2026-06-01',
  'next_payment_count': 2,
  'debt_ratio_bps': debtRatioBps,
  'monthly_income_minor': monthlyIncomeMinor,
  'income_source': incomeSource,
  'hcsf_limit_bps': 3500,
  'over_limit': overLimit,
  'active_count': activeCount,
  'by_lender': [
    {'lender': 'BNP', 'monthly_charge_minor': 122387},
  ],
  'outstanding_series': [
    {'month': '2023-09', 'outstanding_minor': 24000000},
    {'month': '2048-08', 'outstanding_minor': 0},
  ],
  'loan_ends': [
    {'mortgage_id': 'm1', 'label': 'Appartement Lyon 3e', 'month': '2048-08'},
  ],
  'currency': 'EUR',
};

LoanDraft _draftWithDate() => LoanDraft(
  label: 'Travaux cuisine',
  lender: 'Crédit Agricole',
  kind: MortgageKind.works,
  repaymentType: RepaymentType.constantPayment,
  principalMinor: 1500000,
  annualRateBps: 490,
  insuranceMonthlyMinor: 0,
  termMonths: 60,
  firstPaymentDate: DateTime(2025, 3, 1),
);

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        mortgagesTodayProvider.overrideWithValue(() => mortgagesToday),
      ],
    );
    addTearDown(container.dispose);
  });

  void stubLoad({
    List<Map<String, dynamic>>? mortgages,
    Map<String, dynamic>? summary,
  }) {
    when(
      () => apiClient.get('/mortgages', query: any(named: 'query')),
    ).thenAnswer((_) async => mortgages ?? [_mortgageJson()]);
    when(
      () => apiClient.get('/mortgages/summary'),
    ).thenAnswer((_) async => summary ?? _summaryJson());
  }

  group('list', () {
    test('build loads the loans and the summary together', () async {
      stubLoad();

      final state = await container.read(mortgagesControllerProvider.future);

      expect(state.mortgages, hasLength(1));
      final loan = state.mortgages.single;
      expect(loan.label, 'Appartement Lyon 3e');
      expect(loan.kind, MortgageKind.mortgage);
      expect(loan.repaymentType, RepaymentType.constantPayment);
      expect(loan.totalInstalmentMinor, 122387);
      expect(loan.paidPrincipalBps, 727);
      expect(loan.nextPaymentOn, DateTime(2026, 6, 1));
      expect(state.summary.monthlyChargeMinor, 150625);
      expect(state.statusFilter, isNull);
      verify(() => apiClient.get('/mortgages', query: const {})).called(1);
    });

    test('filtering by status re-reads the list under that status', () async {
      stubLoad();
      await container.read(mortgagesControllerProvider.future);

      await container
          .read(mortgagesControllerProvider.notifier)
          .setStatusFilter(MortgageStatus.archived);

      final state = container.read(mortgagesControllerProvider).value!;
      expect(state.statusFilter, MortgageStatus.archived);
      verify(
        () => apiClient.get('/mortgages', query: {'status': 'archived'}),
      ).called(1);
    });

    test('a failed reload surfaces as an error state', () async {
      stubLoad();
      await container.read(mortgagesControllerProvider.future);

      when(
        () => apiClient.get('/mortgages/summary'),
      ).thenThrow(const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom'));
      await container.read(mortgagesControllerProvider.notifier).refresh();

      final state = container.read(mortgagesControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as ApiFailure).code, 'UNKNOWN_ERROR');
    });
  });

  group('summary mapping', () {
    for (final (source, ratio, income) in [
      ('declared', 3274, 460000),
      ('ledger', 5285, 285000),
    ]) {
      test('maps a $source income with its ratio', () async {
        stubLoad(
          summary: _summaryJson(
            incomeSource: source,
            debtRatioBps: ratio,
            monthlyIncomeMinor: income,
            overLimit: source == 'ledger',
          ),
        );

        final summary = (await container.read(
          mortgagesControllerProvider.future,
        )).summary;

        expect(summary.incomeSource, IncomeSource.fromWire(source));
        expect(summary.debtRatioBps, ratio);
        expect(summary.monthlyIncomeMinor, income);
        expect(summary.overLimit, source == 'ledger');
        expect(summary.hcsfLimitBps, 3500);
        expect(summary.byLender.single.lender, 'BNP');
        expect(summary.outstandingSeries.first.month, DateTime(2023, 9));
        expect(summary.loanEnds.single.month, DateTime(2048, 8));
      });
    }

    test('maps an unknown income to a null ratio, never a zero', () async {
      stubLoad(
        summary: _summaryJson(
          incomeSource: 'unknown',
          debtRatioBps: null,
          monthlyIncomeMinor: null,
        ),
      );

      final summary = (await container.read(
        mortgagesControllerProvider.future,
      )).summary;

      expect(summary.incomeSource, IncomeSource.unknown);
      expect(summary.debtRatioBps, isNull);
      expect(summary.monthlyIncomeMinor, isNull);
    });
  });

  group('writes', () {
    test(
      'create posts the declared inputs and reloads list and summary',
      () async {
        stubLoad();
        when(
          () => apiClient.post('/mortgages', body: any(named: 'body')),
        ).thenAnswer((_) async => _detailJson(id: 'm2'));
        await container.read(mortgagesControllerProvider.future);

        await container
            .read(mortgagesControllerProvider.notifier)
            .create(_draftWithDate());

        final body =
            verify(
                  () => apiClient.post(
                    '/mortgages',
                    body: captureAny(named: 'body'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(body, {
          'label': 'Travaux cuisine',
          'lender': 'Crédit Agricole',
          'kind': 'works',
          'repayment_type': 'constant_payment',
          'principal_minor': 1500000,
          'annual_rate_bps': 490,
          'insurance_monthly_minor': 0,
          'term_months': 60,
          'first_payment_date': '2025-03-01',
          'upfront_fees_minor': 0,
        });
        verify(() => apiClient.get('/mortgages/summary')).called(2);
      },
    );

    test('a refused create is rethrown for the form to show inline', () async {
      stubLoad();
      when(
        () => apiClient.post('/mortgages', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'MORTGAGE_NON_AMORTIZING', message: 'no'),
      );
      await container.read(mortgagesControllerProvider.future);

      await expectLater(
        container
            .read(mortgagesControllerProvider.notifier)
            .create(_draftWithDate()),
        throwsA(isA<ApiFailure>()),
      );
      expect(container.read(mortgagesControllerProvider).hasValue, isTrue);
    });

    test(
      'patch sends the kind without touching the repayment type it was given',
      () async {
        stubLoad();
        when(
          () => apiClient.patch('/mortgages/m1', body: any(named: 'body')),
        ).thenAnswer((_) async => _detailJson());
        await container.read(mortgagesControllerProvider.future);

        await container
            .read(mortgagesControllerProvider.notifier)
            .updateLoan('m1', _draftWithDate());

        final body =
            verify(
                  () => apiClient.patch(
                    '/mortgages/m1',
                    body: captureAny(named: 'body'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(body['kind'], 'works');
        expect(body['repayment_type'], 'constant_payment');
        expect(body.containsKey('property_id'), isFalse);
      },
    );

    test(
      'archive deletes, then the reload drops the loan from list and summary',
      () async {
        var archived = false;
        when(
          () => apiClient.get('/mortgages', query: any(named: 'query')),
        ).thenAnswer(
          (_) async => archived ? <Map<String, dynamic>>[] : [_mortgageJson()],
        );
        when(
          () => apiClient.get('/mortgages/summary'),
        ).thenAnswer((_) async => _summaryJson(activeCount: archived ? 0 : 1));
        when(() => apiClient.delete('/mortgages/m1')).thenAnswer((_) async {
          archived = true;
          return null;
        });
        await container.read(mortgagesControllerProvider.future);

        await container
            .read(mortgagesControllerProvider.notifier)
            .archive('m1');

        final state = container.read(mortgagesControllerProvider).value!;
        expect(state.mortgages, isEmpty);
        expect(state.summary.activeCount, 0);
      },
    );

    test('restore patches the status back to active', () async {
      stubLoad();
      when(
        () => apiClient.patch('/mortgages/m1', body: any(named: 'body')),
      ).thenAnswer((_) async => _detailJson());
      await container.read(mortgagesControllerProvider.future);

      await container.read(mortgagesControllerProvider.notifier).restore('m1');

      verify(
        () => apiClient.patch('/mortgages/m1', body: {'status': 'active'}),
      ).called(1);
      expect(
        container.read(mortgagesControllerProvider).value!.actionError,
        isNull,
      );
    });

    test(
      'a refused restore is kept as an action error and the list stays',
      () async {
        stubLoad();
        when(
          () => apiClient.patch('/mortgages/m1', body: any(named: 'body')),
        ).thenThrow(
          const ApiFailure(code: 'MORTGAGE_NOT_FOUND', message: 'gone'),
        );
        await container.read(mortgagesControllerProvider.future);

        await container
            .read(mortgagesControllerProvider.notifier)
            .restore('m1');

        final state = container.read(mortgagesControllerProvider).value!;
        expect(state.actionError, isA<ApiFailure>());
        expect(state.mortgages, hasLength(1));
      },
    );

    test(
      'declaring an income patches settings and re-reads the summary',
      () async {
        var declared = false;
        stubLoad();
        when(() => apiClient.get('/mortgages/summary')).thenAnswer(
          (_) async => declared
              ? _summaryJson(incomeSource: 'declared', debtRatioBps: 3274)
              : _summaryJson(
                  incomeSource: 'unknown',
                  debtRatioBps: null,
                  monthlyIncomeMinor: null,
                ),
        );
        when(
          () => apiClient.patch('/settings', body: any(named: 'body')),
        ).thenAnswer((_) async {
          declared = true;
          return <String, dynamic>{};
        });
        await container.read(mortgagesControllerProvider.future);

        await container
            .read(mortgagesControllerProvider.notifier)
            .declareIncome(460000);

        verify(
          () => apiClient.patch(
            '/settings',
            body: {'declared_monthly_income_minor': 460000},
          ),
        ).called(1);
        final summary = container
            .read(mortgagesControllerProvider)
            .value!
            .summary;
        expect(summary.incomeSource, IncomeSource.declared);
        expect(summary.debtRatioBps, 3274);
      },
    );
  });

  group('schedule window', () {
    Map<String, dynamic> monthsJson() => {
      'granularity': 'month',
      'rows': [
        for (var month = 1; month <= 12; month++)
          {
            'ordinal': 28 + month,
            'due_on': '2026-${month.toString().padLeft(2, '0')}-01',
            'instalment_minor': 122387,
            'interest_minor': 64140,
            'principal_minor': 55367,
            'insurance_minor': 2880,
            'outstanding_after_minor': 22254270,
          },
      ],
      'totals': {
        'interest_minor': 766782,
        'principal_minor': 667302,
        'insurance_minor': 34560,
      },
      'currency': 'EUR',
    };

    Map<String, dynamic> yearJson() => {
      'granularity': 'year',
      'rows': [
        {
          'year': 2026,
          'instalment_minor': 1468644,
          'interest_minor': 766782,
          'principal_minor': 667302,
          'insurance_minor': 34560,
          'outstanding_after_minor': 21862220,
        },
      ],
      'totals': {
        'interest_minor': 766782,
        'principal_minor': 667302,
        'insurance_minor': 34560,
      },
      'currency': 'EUR',
    };

    test(
      'one year is read as its month rows plus the yearly aggregate',
      () async {
        when(
          () => apiClient.get(
            '/mortgages/m1/schedule',
            query: any(named: 'query'),
          ),
        ).thenAnswer((invocation) async {
          final query =
              invocation.namedArguments[#query] as Map<String, String>;
          return query['granularity'] == 'year' ? yearJson() : monthsJson();
        });

        final window = await container.read(
          scheduleWindowProvider((mortgageId: 'm1', year: 2026)).future,
        );

        expect(window.rows, hasLength(12));
        expect(window.rows.first.dueOn, DateTime(2026, 1, 1));
        expect(window.interestMinor, 766782);
        expect(window.insuranceMinor, 34560);
        expect(window.instalmentMinor, 1468644);
        expect(window.outstandingAtYearEndMinor, 21862220);
        verify(
          () => apiClient.get(
            '/mortgages/m1/schedule',
            query: {
              'from': '2026-01-01',
              'to': '2026-12-31',
              'granularity': 'month',
            },
          ),
        ).called(1);
      },
    );

    test(
      'the year opens on the current instalment and pages within the loan',
      () {
        final years = ScheduleYears.of(testDetail(), mortgagesToday);
        final provider = scheduleYearControllerProvider(years);

        // Next payment 01/06/2026, so the current instalment is May 2026.
        expect(years.currentInstalmentMonth, DateTime(2026, 5));
        expect(container.read(provider), 2026);
        expect(years.positionOf(2026), 4);
        expect(years.yearCount, 26);

        container.read(provider.notifier).step(1);
        expect(container.read(provider), 2027);

        container.read(provider.notifier).select(2023);
        container.read(provider.notifier).step(-1);
        expect(
          container.read(provider),
          2023,
          reason: 'nothing before the first year',
        );

        container.read(provider.notifier).select(2100);
        expect(
          container.read(provider),
          2048,
          reason: 'nothing after the last year',
        );
      },
    );

    test(
      'a loan not started yet opens on its first year with no current row',
      () {
        final future = testDetail(
          mortgage: testMortgage(firstPaymentDate: DateTime(2027, 1, 1)),
        );

        final years = ScheduleYears.of(future, mortgagesToday);

        expect(years.currentInstalmentMonth, isNull);
        expect(years.openingYear, 2027);
      },
    );

    test('the detail carries the interest still due after today', () async {
      when(
        () => apiClient.get('/mortgages/m1'),
      ).thenAnswer((_) async => _detailJson());
      when(
        () =>
            apiClient.get('/mortgages/m1/schedule', query: any(named: 'query')),
      ).thenAnswer(
        (_) async => {
          'granularity': 'year',
          'rows': <Map<String, dynamic>>[],
          'totals': {
            'interest_minor': 9240674,
            'principal_minor': 0,
            'insurance_minor': 0,
          },
          'currency': 'EUR',
        },
      );

      final view = await container.read(mortgageDetailProvider('m1').future);

      expect(view.detail.taegBps, 379);
      expect(view.interestStillDueMinor, 9240674);
      verify(
        () => apiClient.get(
          '/mortgages/m1/schedule',
          query: {'from': '2026-05-15', 'granularity': 'year'},
        ),
      ).called(1);
    });
  });
}
