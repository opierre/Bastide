import 'package:finstride/features/simulator/domain/simulation.dart';
import 'package:finstride/features/simulator/domain/simulation_result.dart';

/// The frame's live simulation (`14-simulateur.md` ①): 320 000 € with 40 000 €
/// down and 4 500 € of fees, 3,25 % over 25 years, 32 € of insurance a month.
const testTerms = SimulationTerms(
  principalMinor: 28450000,
  annualRateBps: 325,
  insuranceMonthlyMinor: 3200,
  termMonths: 300,
  upfrontFeesMinor: 450000,
  propertyPriceMinor: 32000000,
  downPaymentMinor: 4000000,
);

HouseholdContext testHousehold({
  int existingChargeMinor = 150625,
  int? monthlyIncomeMinor = 460000,
  IncomeSource incomeSource = IncomeSource.declared,
}) => HouseholdContext(
  existingChargeMinor: existingChargeMinor,
  monthlyIncomeMinor: monthlyIncomeMinor,
  incomeSource: incomeSource,
  currency: 'EUR',
);

SimulationResult testResult({
  int monthlyPaymentMinor = 138641,
  int totalInstalmentMinor = 141841,
  int? costOverPriceBps = 4548,
  int? debtRatioBps = 3084,
  bool? withinRatio = true,
  bool withinTerm = true,
  int? maxBorrowableMinor = 32292849,
  int? availableInstalmentMinor = 161000,
  int years = 25,
}) => SimulationResult(
  monthlyPaymentMinor: monthlyPaymentMinor,
  totalInstalmentMinor: totalInstalmentMinor,
  totalInterestMinor: 13142300,
  totalInsuranceMinor: 960000,
  totalCostMinor: 14552300,
  costOverPriceBps: costOverPriceBps,
  taegBps: 367,
  yearly: [
    for (var index = 0; index < years; index++)
      SimulationYear(
        year: 2026 + index,
        instalmentMinor: 1663692,
        interestMinor: 900000 - index * 30000,
        principalMinor: 763692 + index * 30000,
        insuranceMinor: 38400,
        outstandingAfterMinor: 28450000 - (index + 1) * 1138000,
      ),
  ],
  debtRatioBps: debtRatioBps,
  hcsf: HcsfReading(
    withinRatio: withinRatio,
    withinTerm: withinTerm,
    limitBps: 3500,
    maxTermMonths: 300,
  ),
  maxBorrowableMinor: maxBorrowableMinor,
  availableInstalmentMinor: availableInstalmentMinor,
  currency: 'EUR',
);

/// The frame's over-reference reading (②): existing loans counted.
SimulationResult testOverLimitResult() => testResult(
  debtRatioBps: 6358,
  withinRatio: false,
  maxBorrowableMinor: 2080983,
  availableInstalmentMinor: 10375,
);

/// No income: the ratio, the capacity and the available instalment are absent.
SimulationResult testUnknownIncomeResult() => testResult(
  debtRatioBps: null,
  withinRatio: null,
  maxBorrowableMinor: null,
  availableInstalmentMinor: null,
);

SavedSimulation testScenario({
  String id = 's1',
  String label = 'Villeurbanne — 265 k€',
  SimulationTerms terms = const SimulationTerms(
    principalMinor: 22890000,
    annualRateBps: 325,
    insuranceMonthlyMinor: 0,
    termMonths: 300,
    upfrontFeesMinor: 390000,
    propertyPriceMinor: 26500000,
    downPaymentMinor: 4000000,
  ),
}) => SavedSimulation(id: id, label: label, terms: terms, currency: 'EUR');

Map<String, dynamic> resultJson({
  int? debtRatioBps = 3084,
  bool? withinRatio = true,
  int? maxBorrowableMinor = 32292849,
  int? availableInstalmentMinor = 161000,
  int? costOverPriceBps = 4548,
  int totalInstalmentMinor = 141841,
}) => {
  'monthly_payment_minor': 138641,
  'total_instalment_minor': totalInstalmentMinor,
  'total_interest_minor': 13142300,
  'total_insurance_minor': 960000,
  'total_cost_minor': 14552300,
  'cost_over_price_bps': costOverPriceBps,
  'taeg_bps': 367,
  'yearly': [
    {
      'year': 2026,
      'instalment_minor': 1134922,
      'interest_minor': 616000,
      'principal_minor': 493322,
      'insurance_minor': 25600,
      'outstanding_after_minor': 27956678,
    },
  ],
  'debt_ratio_bps': debtRatioBps,
  'hcsf': {
    'within_ratio': withinRatio,
    'within_term': true,
    'limit_bps': 3500,
    'max_term_months': 300,
  },
  'max_borrowable_minor': maxBorrowableMinor,
  'available_instalment_minor': availableInstalmentMinor,
  'currency': 'EUR',
};

Map<String, dynamic> scenarioJson({
  String id = 's1',
  String label = 'Villeurbanne — 265 k€',
}) => {
  'id': id,
  'label': label,
  'property_price_minor': 26500000,
  'down_payment_minor': 4000000,
  'principal_minor': 22890000,
  'annual_rate_bps': 325,
  'insurance_monthly_minor': 0,
  'term_months': 300,
  'upfront_fees_minor': 390000,
  'currency': 'EUR',
  'created_at': '2026-05-01T00:00:00',
  'updated_at': '2026-05-01T00:00:00',
};

Map<String, dynamic> householdJson({
  int? monthlyIncomeMinor = 460000,
  String incomeSource = 'declared',
}) => {
  'monthly_charge_minor': 150625,
  'total_outstanding_minor': 23412921,
  'total_principal_minor': 25500000,
  'repaid_principal_minor': 2087079,
  'repaid_pct_bps': 818,
  'next_payment_on': '2026-06-01',
  'next_payment_count': 2,
  'debt_ratio_bps': 3274,
  'monthly_income_minor': monthlyIncomeMinor,
  'income_source': incomeSource,
  'hcsf_limit_bps': 3500,
  'over_limit': false,
  'active_count': 2,
  'by_lender': const [],
  'outstanding_series': const [],
  'loan_ends': const [],
  'currency': 'EUR',
};
