import 'package:finstride/features/mortgages/application/mortgages_controller.dart';
import 'package:finstride/features/mortgages/domain/mortgage.dart';
import 'package:finstride/features/mortgages/domain/schedule_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// May 2026 — the month every mockup and fixture in the project is set in.
final mortgagesToday = DateTime(2026, 5, 14);

/// The frame's crédit immobilier (`12-credits.md` card 1).
Mortgage testMortgage({
  String id = 'm1',
  String label = 'Appartement Lyon 3e',
  String lender = 'BNP',
  MortgageKind kind = MortgageKind.mortgage,
  RepaymentType repaymentType = RepaymentType.constantPayment,
  int principalMinor = 24000000,
  int annualRateBps = 345,
  int insuranceMonthlyMinor = 2880,
  int termMonths = 300,
  DateTime? firstPaymentDate,
  int upfrontFeesMinor = 145000,
  String? propertyId,
  MortgageStatus status = MortgageStatus.active,
  int monthlyPaymentMinor = 119507,
  int totalInstalmentMinor = 122387,
  int outstandingPrincipalMinor = 22254270,
  int paidPrincipalBps = 727,
  int remainingMonths = 267,
  DateTime? nextPaymentOn,
}) => Mortgage(
  id: id,
  label: label,
  lender: lender,
  propertyId: propertyId,
  kind: kind,
  repaymentType: repaymentType,
  principalMinor: principalMinor,
  annualRateBps: annualRateBps,
  insuranceMonthlyMinor: insuranceMonthlyMinor,
  termMonths: termMonths,
  firstPaymentDate: firstPaymentDate ?? DateTime(2023, 9, 1),
  upfrontFeesMinor: upfrontFeesMinor,
  status: status,
  currency: 'EUR',
  monthlyPaymentMinor: monthlyPaymentMinor,
  totalInstalmentMinor: totalInstalmentMinor,
  outstandingPrincipalMinor: outstandingPrincipalMinor,
  paidPrincipalBps: paidPrincipalBps,
  remainingMonths: remainingMonths,
  nextPaymentOn: nextPaymentOn ?? DateTime(2026, 6, 1),
);

/// The frame's prêt travaux (`12-credits.md` card 2).
Mortgage testWorksLoan() => testMortgage(
  id: 'm2',
  label: 'Travaux cuisine',
  lender: 'Crédit Agricole',
  kind: MortgageKind.works,
  principalMinor: 1500000,
  annualRateBps: 490,
  insuranceMonthlyMinor: 0,
  termMonths: 60,
  firstPaymentDate: DateTime(2025, 3, 1),
  upfrontFeesMinor: 0,
  monthlyPaymentMinor: 28238,
  totalInstalmentMinor: 28238,
  outstandingPrincipalMinor: 1158651,
  paidPrincipalBps: 2276,
  remainingMonths: 45,
);

MortgageDetail testDetail({Mortgage? mortgage}) => MortgageDetail(
  mortgage: mortgage ?? testMortgage(),
  totalInterestMinor: 11852100,
  totalInsuranceMinor: 864000,
  totalCostMinor: 12861100,
  taegBps: 379,
  lastPaymentOn: DateTime(2048, 8, 1),
);

MortgageSummary testMortgageSummary({
  int? debtRatioBps = 3274,
  int? monthlyIncomeMinor = 460000,
  IncomeSource incomeSource = IncomeSource.declared,
  bool overLimit = false,
  int activeCount = 2,
  List<OutstandingPoint>? outstandingSeries,
  List<LoanEndMarker>? loanEnds,
}) => MortgageSummary(
  monthlyChargeMinor: 150625,
  totalOutstandingMinor: 23412921,
  totalPrincipalMinor: 25500000,
  repaidPrincipalMinor: 2087079,
  repaidBps: 818,
  nextPaymentOn: DateTime(2026, 6, 1),
  nextPaymentCount: 2,
  debtRatioBps: debtRatioBps,
  monthlyIncomeMinor: monthlyIncomeMinor,
  incomeSource: incomeSource,
  hcsfLimitBps: 3500,
  overLimit: overLimit,
  activeCount: activeCount,
  byLender: const [
    LenderCharge(lender: 'BNP', monthlyChargeMinor: 122387),
    LenderCharge(lender: 'Crédit Agricole', monthlyChargeMinor: 28238),
  ],
  outstandingSeries:
      outstandingSeries ??
      [
        OutstandingPoint(month: DateTime(2023, 9), outstandingMinor: 24000000),
        OutstandingPoint(month: DateTime(2025, 3), outstandingMinor: 25500000),
        OutstandingPoint(month: DateTime(2026, 5), outstandingMinor: 23412921),
        OutstandingPoint(month: DateTime(2030, 2), outstandingMinor: 19000000),
        OutstandingPoint(month: DateTime(2048, 8), outstandingMinor: 0),
      ],
  loanEnds:
      loanEnds ??
      [
        LoanEndMarker(
          mortgageId: 'm2',
          label: 'Travaux cuisine',
          month: DateTime(2030, 2),
        ),
        LoanEndMarker(
          mortgageId: 'm1',
          label: 'Appartement Lyon 3e',
          month: DateTime(2048, 8),
        ),
      ],
  currency: 'EUR',
);

ScheduleRow testScheduleRow(
  int month, {
  int outstandingAfterMinor = 22254270,
}) => ScheduleRow(
  ordinal: 32 + month,
  dueOn: DateTime(2026, month),
  instalmentMinor: 122387,
  interestMinor: 64140,
  principalMinor: 55367,
  insuranceMinor: 2880,
  outstandingAfterMinor: outstandingAfterMinor,
);

ScheduleYear testScheduleYear({int year = 2026}) => ScheduleYear(
  year: year,
  rows: [for (var month = 1; month <= 12; month++) testScheduleRow(month)],
  interestMinor: 766782,
  principalMinor: 667302,
  insuranceMinor: 34560,
  instalmentMinor: 1468644,
  outstandingAtYearEndMinor: 21862220,
  currency: 'EUR',
);

/// A no-network [MortgagesController] double for widget tests: a fixed list and
/// summary, plus a record of the writes the panel attempted.
class FakeMortgagesController extends MortgagesController {
  FakeMortgagesController({
    this.initialMortgages = const [],
    MortgageSummary? summary,
    this.loadError,
  }) : summary = summary ?? testMortgageSummary();

  final List<Mortgage> initialMortgages;
  final MortgageSummary summary;
  final Object? loadError;

  final createCalls = <LoanDraft>[];
  final updateCalls = <(String, LoanDraft)>[];
  final archiveCalls = <String>[];
  final declaredIncomes = <int>[];
  Object? errorOnSave;

  @override
  Future<MortgagesState> build() async {
    if (loadError != null) throw loadError!;
    return MortgagesState(mortgages: initialMortgages, summary: summary);
  }

  @override
  Future<MortgageDetail> create(LoanDraft draft) async {
    if (errorOnSave != null) throw errorOnSave!;
    createCalls.add(draft);
    return testDetail();
  }

  @override
  Future<MortgageDetail> updateLoan(String mortgageId, LoanDraft draft) async {
    if (errorOnSave != null) throw errorOnSave!;
    updateCalls.add((mortgageId, draft));
    return testDetail();
  }

  @override
  Future<void> archive(String mortgageId) async {
    archiveCalls.add(mortgageId);
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        mortgages: [
          for (final mortgage in current.mortgages)
            if (mortgage.id != mortgageId) mortgage,
        ],
      ),
    );
  }

  @override
  Future<void> declareIncome(int monthlyIncomeMinor) async {
    declaredIncomes.add(monthlyIncomeMinor);
  }
}
