import 'package:flutter/foundation.dart';

/// The credit product the panel prints on every card (`PROJECT.md` §4).
///
/// A label only: the schedule never reads it. It is a separate axis from
/// [RepaymentType] — a works loan can be constant-payment or in fine — so
/// neither is ever derived from the other.
enum MortgageKind {
  mortgage('mortgage'),
  works('works'),
  consumer('consumer'),
  auto('auto');

  const MortgageKind(this.wireValue);

  final String wireValue;

  static MortgageKind fromWire(String value) =>
      values.firstWhere((kind) => kind.wireValue == value);
}

/// The maths the schedule runs on.
enum RepaymentType {
  constantPayment('constant_payment'),
  interestOnly('interest_only');

  const RepaymentType(this.wireValue);

  final String wireValue;

  static RepaymentType fromWire(String value) =>
      values.firstWhere((type) => type.wireValue == value);
}

/// Lifecycle status. `repaid` is user intent, never settled from the schedule.
enum MortgageStatus {
  active('active'),
  repaid('repaid'),
  archived('archived');

  const MortgageStatus(this.wireValue);

  final String wireValue;

  static MortgageStatus fromWire(String value) =>
      values.firstWhere((status) => status.wireValue == value);
}

/// Where the debt ratio's denominator came from (`PROJECT.md` §15).
enum IncomeSource {
  declared('declared'),
  ledger('ledger'),
  unknown('unknown');

  const IncomeSource(this.wireValue);

  final String wireValue;

  static IncomeSource fromWire(String value) =>
      values.firstWhere((source) => source.wireValue == value);
}

/// A declared loan with the figures the backend derives from its schedule as of
/// today. Every figure is server-computed: a second amortisation in Dart would
/// drift from the engine the tests pin (§15).
@immutable
class Mortgage {
  const Mortgage({
    required this.id,
    required this.label,
    required this.lender,
    required this.propertyId,
    required this.kind,
    required this.repaymentType,
    required this.principalMinor,
    required this.annualRateBps,
    required this.insuranceMonthlyMinor,
    required this.termMonths,
    required this.firstPaymentDate,
    required this.upfrontFeesMinor,
    required this.status,
    required this.currency,
    required this.monthlyPaymentMinor,
    required this.totalInstalmentMinor,
    required this.outstandingPrincipalMinor,
    required this.paidPrincipalBps,
    required this.remainingMonths,
    required this.nextPaymentOn,
  });

  final String id;
  final String label;
  final String lender;
  final String? propertyId;
  final MortgageKind kind;
  final RepaymentType repaymentType;
  final int principalMinor;
  final int annualRateBps;
  final int insuranceMonthlyMinor;
  final int termMonths;
  final DateTime firstPaymentDate;
  final int upfrontFeesMinor;
  final MortgageStatus status;
  final String currency;

  /// The échéance, insurance excluded.
  final int monthlyPaymentMinor;

  /// The échéance plus insurance — what the card headlines.
  final int totalInstalmentMinor;
  final int outstandingPrincipalMinor;

  /// Share of the principal repaid, in basis points (the wire's
  /// `paid_principal_pct`, which is bps despite its name).
  final int paidPrincipalBps;
  final int remainingMonths;

  /// `null` once the last instalment has passed.
  final DateTime? nextPaymentOn;
}

/// One loan with its cost totals and indicative TAEG on top of the list figures.
@immutable
class MortgageDetail {
  const MortgageDetail({
    required this.mortgage,
    required this.totalInterestMinor,
    required this.totalInsuranceMinor,
    required this.totalCostMinor,
    required this.taegBps,
    required this.lastPaymentOn,
  });

  final Mortgage mortgage;
  final int totalInterestMinor;
  final int totalInsuranceMinor;

  /// Interest, insurance and upfront fees.
  final int totalCostMinor;

  /// Indicative only (§15): a real TAEG includes fees the app never sees.
  final int taegBps;
  final DateTime lastPaymentOn;
}

/// What the detail view reads: the loan, plus the interest still to be paid
/// after today — summed by the schedule endpoint, never here.
@immutable
class MortgageDetailView {
  const MortgageDetailView({
    required this.detail,
    required this.interestStillDueMinor,
  });

  final MortgageDetail detail;
  final int interestStillDueMinor;
}

/// The monthly charge of the active loans held with one lender.
@immutable
class LenderCharge {
  const LenderCharge({required this.lender, required this.monthlyChargeMinor});

  final String lender;
  final int monthlyChargeMinor;
}

/// Combined capital still owed across active loans after one month.
@immutable
class OutstandingPoint {
  const OutstandingPoint({required this.month, required this.outstandingMinor});

  /// First day of the month.
  final DateTime month;
  final int outstandingMinor;
}

/// The month an active loan's last instalment falls in.
@immutable
class LoanEndMarker {
  const LoanEndMarker({
    required this.mortgageId,
    required this.label,
    required this.month,
  });

  final String mortgageId;
  final String label;

  /// First day of the month.
  final DateTime month;
}

/// `GET /mortgages/summary` — the three summary cards, the debt ratio and the
/// trajectory series, all over active loans and all computed server-side.
@immutable
class MortgageSummary {
  const MortgageSummary({
    required this.monthlyChargeMinor,
    required this.totalOutstandingMinor,
    required this.totalPrincipalMinor,
    required this.repaidPrincipalMinor,
    required this.repaidBps,
    required this.nextPaymentOn,
    required this.nextPaymentCount,
    required this.debtRatioBps,
    required this.monthlyIncomeMinor,
    required this.incomeSource,
    required this.hcsfLimitBps,
    required this.overLimit,
    required this.activeCount,
    required this.byLender,
    required this.outstandingSeries,
    required this.loanEnds,
    required this.currency,
  });

  final int monthlyChargeMinor;
  final int totalOutstandingMinor;
  final int totalPrincipalMinor;
  final int repaidPrincipalMinor;
  final int repaidBps;
  final DateTime? nextPaymentOn;
  final int nextPaymentCount;

  /// `null` when the income is unknown: no ratio is invented (§15).
  final int? debtRatioBps;
  final int? monthlyIncomeMinor;
  final IncomeSource incomeSource;
  final int hcsfLimitBps;

  /// Information only — the app makes no lending decisions.
  final bool overLimit;
  final int activeCount;
  final List<LenderCharge> byLender;
  final List<OutstandingPoint> outstandingSeries;
  final List<LoanEndMarker> loanEnds;
  final String currency;
}

/// The declared inputs of a loan, as the form collects them. Rates are already
/// in bps: the percent the user typed is converted at the form edge.
@immutable
class LoanDraft {
  const LoanDraft({
    required this.label,
    required this.lender,
    required this.kind,
    required this.repaymentType,
    required this.principalMinor,
    required this.annualRateBps,
    required this.insuranceMonthlyMinor,
    required this.termMonths,
    required this.firstPaymentDate,
    this.upfrontFeesMinor = 0,
    this.propertyId,
  });

  final String label;
  final String lender;
  final MortgageKind kind;
  final RepaymentType repaymentType;
  final int principalMinor;
  final int annualRateBps;
  final int insuranceMonthlyMinor;
  final int termMonths;
  final DateTime firstPaymentDate;
  final int upfrontFeesMinor;

  /// `null` leaves the loan unlinked — and, on a patch, leaves the link alone.
  final String? propertyId;
}

/// What `POST /simulations/compute` returns that the form's plate prints.
@immutable
class ComputedInstalment {
  const ComputedInstalment({
    required this.monthlyPaymentMinor,
    required this.totalInstalmentMinor,
    required this.totalInterestMinor,
    required this.currency,
  });

  final int monthlyPaymentMinor;
  final int totalInstalmentMinor;
  final int totalInterestMinor;
  final String currency;
}

/// A property a loan can be linked to — this panel's narrow view of one.
@immutable
class LoanProperty {
  const LoanProperty({required this.id, required this.label});

  final String id;
  final String label;
}
