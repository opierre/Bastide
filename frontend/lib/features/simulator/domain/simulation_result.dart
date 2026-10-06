import 'package:flutter/foundation.dart';

/// One calendar year of the simulated schedule, as the engine aggregates it.
/// Capital and interest arrive split, so the projection stacks them without
/// deriving either.
@immutable
class SimulationYear {
  const SimulationYear({
    required this.year,
    required this.instalmentMinor,
    required this.interestMinor,
    required this.principalMinor,
    required this.insuranceMinor,
    required this.outstandingAfterMinor,
  });

  final int year;
  final int instalmentMinor;
  final int interestMinor;
  final int principalMinor;
  final int insuranceMinor;
  final int outstandingAfterMinor;
}

/// The HCSF reference points and where the simulation stands against them.
/// Data, never a verdict: nothing is refused for being outside them.
@immutable
class HcsfReading {
  const HcsfReading({
    required this.withinRatio,
    required this.withinTerm,
    required this.limitBps,
    required this.maxTermMonths,
  });

  /// `null` when the income is unknown and no ratio could be read.
  final bool? withinRatio;
  final bool withinTerm;
  final int limitBps;
  final int maxTermMonths;
}

/// `POST /simulations/compute` — every figure the panel prints, all from the
/// one engine. Nothing here is computed in Dart.
@immutable
class SimulationResult {
  const SimulationResult({
    required this.monthlyPaymentMinor,
    required this.totalInstalmentMinor,
    required this.totalInterestMinor,
    required this.totalInsuranceMinor,
    required this.totalCostMinor,
    required this.costOverPriceBps,
    required this.taegBps,
    required this.yearly,
    required this.debtRatioBps,
    required this.hcsf,
    required this.maxBorrowableMinor,
    required this.availableInstalmentMinor,
    required this.currency,
  });

  /// The échéance, insurance excluded.
  final int monthlyPaymentMinor;

  /// Payment plus insurance — the figure the panel headlines.
  final int totalInstalmentMinor;
  final int totalInterestMinor;
  final int totalInsuranceMinor;

  /// Interest, insurance and upfront fees.
  final int totalCostMinor;

  /// `null` without a property price.
  final int? costOverPriceBps;

  /// Indicative only: a real TAEG includes fees the app never sees.
  final int taegBps;
  final List<SimulationYear> yearly;

  /// `null` when the income is unknown — absent, never zero.
  final int? debtRatioBps;
  final HcsfReading hcsf;

  /// `null` when the income is unknown — absent, never zero.
  final int? maxBorrowableMinor;

  /// The instalment still available under the reference, the capacity's cause.
  final int? availableInstalmentMinor;
  final String currency;
}
