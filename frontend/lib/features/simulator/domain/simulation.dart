import 'package:flutter/foundation.dart';

/// The loan terms `POST /simulations/compute` runs on — everything the engine
/// needs, already in integer minor units and basis points.
@immutable
class SimulationTerms {
  const SimulationTerms({
    required this.principalMinor,
    required this.annualRateBps,
    required this.insuranceMonthlyMinor,
    required this.termMonths,
    required this.upfrontFeesMinor,
    this.propertyPriceMinor,
    this.downPaymentMinor,
  });

  final int principalMinor;
  final int annualRateBps;
  final int insuranceMonthlyMinor;
  final int termMonths;
  final int upfrontFeesMinor;

  /// `null` when no price was entered: the API then has no cost-over-price to
  /// report, and the panel prints a dash rather than a zero.
  final int? propertyPriceMinor;
  final int? downPaymentMinor;

  @override
  bool operator ==(Object other) =>
      other is SimulationTerms &&
      other.principalMinor == principalMinor &&
      other.annualRateBps == annualRateBps &&
      other.insuranceMonthlyMinor == insuranceMonthlyMinor &&
      other.termMonths == termMonths &&
      other.upfrontFeesMinor == upfrontFeesMinor &&
      other.propertyPriceMinor == propertyPriceMinor &&
      other.downPaymentMinor == downPaymentMinor;

  @override
  int get hashCode => Object.hash(
    principalMinor,
    annualRateBps,
    insuranceMonthlyMinor,
    termMonths,
    upfrontFeesMinor,
    propertyPriceMinor,
    downPaymentMinor,
  );
}

/// What the form holds right now. Every figure is optional while it is being
/// typed; [terms] says whether there is enough of a loan to compute.
@immutable
class SimulatorInputs {
  const SimulatorInputs({
    this.propertyPriceMinor,
    this.downPaymentMinor,
    this.upfrontFeesMinor,
    this.principalMinor,
    this.annualRateBps,
    this.insuranceMonthlyMinor,
    this.termMonths = defaultTermMonths,
    this.includeExistingLoans = false,
  });

  /// The slider's range and step (`14-simulateur.md` §Form): 5 to 30 years, a
  /// year at a time, opening on 25.
  static const minTermMonths = 60;
  static const maxTermMonths = 360;
  static const termStepMonths = 12;
  static const defaultTermMonths = 300;

  final int? propertyPriceMinor;
  final int? downPaymentMinor;
  final int? upfrontFeesMinor;
  final int? principalMinor;
  final int? annualRateBps;
  final int? insuranceMonthlyMinor;
  final int termMonths;
  final bool includeExistingLoans;

  /// The computable loan, or `null` until a borrowed amount and a rate exist.
  /// Insurance and fees are optional: blank is none.
  SimulationTerms? get terms {
    final principal = principalMinor;
    final rate = annualRateBps;
    if (principal == null || principal <= 0 || rate == null) return null;
    return SimulationTerms(
      principalMinor: principal,
      annualRateBps: rate,
      insuranceMonthlyMinor: insuranceMonthlyMinor ?? 0,
      termMonths: termMonths,
      upfrontFeesMinor: upfrontFeesMinor ?? 0,
      propertyPriceMinor: propertyPriceMinor,
      downPaymentMinor: downPaymentMinor,
    );
  }

  static const _unset = Object();

  SimulatorInputs copyWith({
    Object? propertyPriceMinor = _unset,
    Object? downPaymentMinor = _unset,
    Object? upfrontFeesMinor = _unset,
    Object? principalMinor = _unset,
    Object? annualRateBps = _unset,
    Object? insuranceMonthlyMinor = _unset,
    int? termMonths,
    bool? includeExistingLoans,
  }) => SimulatorInputs(
    propertyPriceMinor: identical(propertyPriceMinor, _unset)
        ? this.propertyPriceMinor
        : propertyPriceMinor as int?,
    downPaymentMinor: identical(downPaymentMinor, _unset)
        ? this.downPaymentMinor
        : downPaymentMinor as int?,
    upfrontFeesMinor: identical(upfrontFeesMinor, _unset)
        ? this.upfrontFeesMinor
        : upfrontFeesMinor as int?,
    principalMinor: identical(principalMinor, _unset)
        ? this.principalMinor
        : principalMinor as int?,
    annualRateBps: identical(annualRateBps, _unset)
        ? this.annualRateBps
        : annualRateBps as int?,
    insuranceMonthlyMinor: identical(insuranceMonthlyMinor, _unset)
        ? this.insuranceMonthlyMinor
        : insuranceMonthlyMinor as int?,
    termMonths: termMonths ?? this.termMonths,
    includeExistingLoans: includeExistingLoans ?? this.includeExistingLoans,
  );
}

/// A saved scenario: a label over inputs only. No result is ever stored on it
/// — its figures are recomputed whenever they are shown.
@immutable
class SavedSimulation {
  const SavedSimulation({
    required this.id,
    required this.label,
    required this.terms,
    required this.currency,
  });

  final String id;
  final String label;

  /// Always carries a price and a down payment: a scenario cannot be saved
  /// without them.
  final SimulationTerms terms;
  final String currency;
}

/// Where the debt ratio's denominator came from.
enum IncomeSource {
  declared('declared'),
  ledger('ledger'),
  unknown('unknown');

  const IncomeSource(this.wireValue);

  final String wireValue;

  static IncomeSource fromWire(String value) =>
      values.firstWhere((source) => source.wireValue == value);
}

/// The household figures the HCSF reading is stated against — read from
/// `GET /mortgages/summary`, because the compute response carries the ratio
/// but not the income it divided by nor the existing charge it added.
@immutable
class HouseholdContext {
  const HouseholdContext({
    required this.existingChargeMinor,
    required this.monthlyIncomeMinor,
    required this.incomeSource,
    required this.currency,
  });

  /// The active loans' monthly charge, insurance included — what « inclure mes
  /// crédits actuels » adds to the reading.
  final int existingChargeMinor;
  final int? monthlyIncomeMinor;
  final IncomeSource incomeSource;
  final String currency;
}
