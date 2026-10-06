import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/mortgage.dart';
import '../domain/schedule_row.dart';

/// Calls the `/mortgages` endpoints and maps the wire JSON to domain models.
/// The only place in this feature that knows the response shapes.
///
/// It also reaches three foreign resources for this panel's own affordances —
/// `/simulations/compute` for the form's live « Mensualité calculée » plate,
/// `/properties` for the loan's property link, and `PATCH /settings` for the
/// ratio card's « Déclarer un revenu » — the same arrangement the recurring
/// repository uses for accounts and categories.
class MortgagesRepository {
  MortgagesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Mortgage>> list({MortgageStatus? status}) async {
    final json =
        await _apiClient.get(
              '/mortgages',
              query: {if (status != null) 'status': status.wireValue},
            )
            as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>())
        _parseMortgage(entry),
    ];
  }

  Future<MortgageSummary> summary() async {
    final json =
        await _apiClient.get('/mortgages/summary') as Map<String, dynamic>;
    return _parseSummary(json);
  }

  Future<MortgageDetail> detail(String mortgageId) async {
    final json =
        await _apiClient.get('/mortgages/$mortgageId') as Map<String, dynamic>;
    return _parseDetail(json);
  }

  Future<MortgageDetail> create(LoanDraft draft) async {
    final json =
        await _apiClient.post('/mortgages', body: _draftJson(draft))
            as Map<String, dynamic>;
    return _parseDetail(json);
  }

  /// Patches a loan with every declared input. `property_id` is only sent when
  /// set: `null` is indistinguishable from absent on this API, so unlinking is
  /// not expressible.
  Future<MortgageDetail> update(String mortgageId, LoanDraft draft) async {
    final json =
        await _apiClient.patch(
              '/mortgages/$mortgageId',
              body: _draftJson(draft),
            )
            as Map<String, dynamic>;
    return _parseDetail(json);
  }

  Future<MortgageDetail> setStatus(
    String mortgageId,
    MortgageStatus status,
  ) async {
    final json =
        await _apiClient.patch(
              '/mortgages/$mortgageId',
              body: {'status': status.wireValue},
            )
            as Map<String, dynamic>;
    return _parseDetail(json);
  }

  /// Archives the loan — the API never hard-deletes one.
  Future<void> archive(String mortgageId) =>
      _apiClient.delete('/mortgages/$mortgageId');

  /// One calendar year of the schedule, read twice from the same window: the
  /// month rows with their totals, and the yearly aggregate for the foot's
  /// « Total versé » and year-end outstanding. Both are the engine's sums.
  Future<ScheduleYear> scheduleYear(String mortgageId, int year) async {
    final window = {'from': '$year-01-01', 'to': '$year-12-31'};
    final months =
        await _apiClient.get(
              '/mortgages/$mortgageId/schedule',
              query: {...window, 'granularity': 'month'},
            )
            as Map<String, dynamic>;
    final years =
        await _apiClient.get(
              '/mortgages/$mortgageId/schedule',
              query: {...window, 'granularity': 'year'},
            )
            as Map<String, dynamic>;

    final totals = months['totals'] as Map<String, dynamic>;
    final yearRows = (years['rows'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final yearRow = yearRows.isEmpty ? null : yearRows.first;

    return ScheduleYear(
      year: year,
      rows: [
        for (final row
            in (months['rows'] as List<dynamic>).cast<Map<String, dynamic>>())
          ScheduleRow(
            ordinal: row['ordinal'] as int,
            dueOn: DateTime.parse(row['due_on'] as String),
            instalmentMinor: row['instalment_minor'] as int,
            interestMinor: row['interest_minor'] as int,
            principalMinor: row['principal_minor'] as int,
            insuranceMinor: row['insurance_minor'] as int,
            outstandingAfterMinor: row['outstanding_after_minor'] as int,
          ),
      ],
      interestMinor: totals['interest_minor'] as int,
      principalMinor: totals['principal_minor'] as int,
      insuranceMinor: totals['insurance_minor'] as int,
      instalmentMinor: (yearRow?['instalment_minor'] as int?) ?? 0,
      outstandingAtYearEndMinor:
          (yearRow?['outstanding_after_minor'] as int?) ?? 0,
      currency: months['currency'] as String,
    );
  }

  /// The interest of every instalment due after [day], as the schedule
  /// endpoint totals it.
  Future<int> interestDueAfter(String mortgageId, DateTime day) async {
    final json =
        await _apiClient.get(
              '/mortgages/$mortgageId/schedule',
              query: {
                'from': _date(DateTime(day.year, day.month, day.day + 1)),
                'granularity': 'year',
              },
            )
            as Map<String, dynamic>;
    return (json['totals'] as Map<String, dynamic>)['interest_minor'] as int;
  }

  /// The stateless simulator run behind the form's live plate (one engine
  /// for a simulated loan and a declared one).
  Future<ComputedInstalment> compute({
    required int principalMinor,
    required int annualRateBps,
    required int insuranceMonthlyMinor,
    required int termMonths,
    required int upfrontFeesMinor,
  }) async {
    final json =
        await _apiClient.post(
              '/simulations/compute',
              body: {
                'principal_minor': principalMinor,
                'annual_rate_bps': annualRateBps,
                'insurance_monthly_minor': insuranceMonthlyMinor,
                'term_months': termMonths,
                'upfront_fees_minor': upfrontFeesMinor,
              },
            )
            as Map<String, dynamic>;
    return ComputedInstalment(
      monthlyPaymentMinor: json['monthly_payment_minor'] as int,
      totalInstalmentMinor: json['total_instalment_minor'] as int,
      totalInterestMinor: json['total_interest_minor'] as int,
      currency: json['currency'] as String,
    );
  }

  Future<List<LoanProperty>> listProperties() async {
    final json = await _apiClient.get('/properties') as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>())
        LoanProperty(
          id: entry['id'] as String,
          label: entry['label'] as String,
        ),
    ];
  }

  /// Declares the monthly income the debt ratio runs on.
  Future<void> declareIncome(int monthlyIncomeMinor) => _apiClient.patch(
    '/settings',
    body: {'declared_monthly_income_minor': monthlyIncomeMinor},
  );

  Map<String, dynamic> _draftJson(LoanDraft draft) => {
    'label': draft.label,
    'lender': draft.lender,
    'kind': draft.kind.wireValue,
    'repayment_type': draft.repaymentType.wireValue,
    'principal_minor': draft.principalMinor,
    'annual_rate_bps': draft.annualRateBps,
    'insurance_monthly_minor': draft.insuranceMonthlyMinor,
    'term_months': draft.termMonths,
    'first_payment_date': _date(draft.firstPaymentDate),
    'upfront_fees_minor': draft.upfrontFeesMinor,
    'property_id': ?draft.propertyId,
  };

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime _month(String value) => DateTime.parse('$value-01');

  static DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  Mortgage _parseMortgage(Map<String, dynamic> json) => Mortgage(
    id: json['id'] as String,
    label: json['label'] as String,
    lender: json['lender'] as String,
    propertyId: json['property_id'] as String?,
    kind: MortgageKind.fromWire(json['kind'] as String),
    repaymentType: RepaymentType.fromWire(json['repayment_type'] as String),
    principalMinor: json['principal_minor'] as int,
    annualRateBps: json['annual_rate_bps'] as int,
    insuranceMonthlyMinor: json['insurance_monthly_minor'] as int,
    termMonths: json['term_months'] as int,
    firstPaymentDate: DateTime.parse(json['first_payment_date'] as String),
    upfrontFeesMinor: json['upfront_fees_minor'] as int,
    status: MortgageStatus.fromWire(json['status'] as String),
    currency: json['currency'] as String,
    monthlyPaymentMinor: json['monthly_payment_minor'] as int,
    totalInstalmentMinor: json['total_instalment_minor'] as int,
    outstandingPrincipalMinor: json['outstanding_principal_minor'] as int,
    paidPrincipalBps: json['paid_principal_pct'] as int,
    remainingMonths: json['remaining_months'] as int,
    nextPaymentOn: _optionalDate(json['next_payment_on']),
  );

  MortgageDetail _parseDetail(Map<String, dynamic> json) => MortgageDetail(
    mortgage: _parseMortgage(json),
    totalInterestMinor: json['total_interest_minor'] as int,
    totalInsuranceMinor: json['total_insurance_minor'] as int,
    totalCostMinor: json['total_cost_minor'] as int,
    taegBps: json['taeg_bps'] as int,
    lastPaymentOn: DateTime.parse(json['last_payment_on'] as String),
  );

  MortgageSummary _parseSummary(Map<String, dynamic> json) => MortgageSummary(
    monthlyChargeMinor: json['monthly_charge_minor'] as int,
    totalOutstandingMinor: json['total_outstanding_minor'] as int,
    totalPrincipalMinor: json['total_principal_minor'] as int,
    repaidPrincipalMinor: json['repaid_principal_minor'] as int,
    repaidBps: json['repaid_pct_bps'] as int,
    nextPaymentOn: _optionalDate(json['next_payment_on']),
    nextPaymentCount: json['next_payment_count'] as int,
    debtRatioBps: json['debt_ratio_bps'] as int?,
    monthlyIncomeMinor: json['monthly_income_minor'] as int?,
    incomeSource: IncomeSource.fromWire(json['income_source'] as String),
    hcsfLimitBps: json['hcsf_limit_bps'] as int,
    overLimit: json['over_limit'] as bool,
    activeCount: json['active_count'] as int,
    byLender: [
      for (final entry
          in (json['by_lender'] as List<dynamic>).cast<Map<String, dynamic>>())
        LenderCharge(
          lender: entry['lender'] as String,
          monthlyChargeMinor: entry['monthly_charge_minor'] as int,
        ),
    ],
    outstandingSeries: [
      for (final entry
          in (json['outstanding_series'] as List<dynamic>)
              .cast<Map<String, dynamic>>())
        OutstandingPoint(
          month: _month(entry['month'] as String),
          outstandingMinor: entry['outstanding_minor'] as int,
        ),
    ],
    loanEnds: [
      for (final entry
          in (json['loan_ends'] as List<dynamic>).cast<Map<String, dynamic>>())
        LoanEndMarker(
          mortgageId: entry['mortgage_id'] as String,
          label: entry['label'] as String,
          month: _month(entry['month'] as String),
        ),
    ],
    currency: json['currency'] as String,
  );
}

final mortgagesRepositoryProvider = Provider<MortgagesRepository>((ref) {
  return MortgagesRepository(ref.watch(apiClientProvider));
});
