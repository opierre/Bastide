import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/simulation.dart';
import '../domain/simulation_result.dart';

/// Calls the `/simulations` endpoints and maps the wire JSON to domain models.
/// The only place in this feature that knows the response shapes.
///
/// It also reaches two foreign resources for this panel's HCSF reading —
/// `GET /mortgages/summary` for the income and the existing charge the reading
/// is stated against, and `PATCH /settings` for « Déclarer un revenu » — the
/// same arrangement the Crédits repository uses for `/simulations/compute`.
class SimulationsRepository {
  SimulationsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// The saved scenarios, oldest first.
  Future<List<SavedSimulation>> list() async {
    final json = await _apiClient.get('/simulations') as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>()) _parseSaved(entry),
    ];
  }

  /// Saves a scenario's inputs. The terms must carry a property price.
  Future<SavedSimulation> create(String label, SimulationTerms terms) async {
    final json =
        await _apiClient.post(
              '/simulations',
              body: {
                'label': label,
                'property_price_minor': terms.propertyPriceMinor,
                'down_payment_minor': terms.downPaymentMinor ?? 0,
                'principal_minor': terms.principalMinor,
                'annual_rate_bps': terms.annualRateBps,
                'insurance_monthly_minor': terms.insuranceMonthlyMinor,
                'term_months': terms.termMonths,
                'upfront_fees_minor': terms.upfrontFeesMinor,
              },
            )
            as Map<String, dynamic>;
    return _parseSaved(json);
  }

  /// Hard-deletes a scenario — a scratchpad row, not history (§5).
  Future<void> delete(String simulationId) =>
      _apiClient.delete('/simulations/$simulationId');

  /// The stateless compute. Persists nothing, so it is safe on every
  /// debounced keystroke.
  Future<SimulationResult> compute(
    SimulationTerms terms, {
    required bool includeExistingLoans,
  }) async {
    final json =
        await _apiClient.post(
              '/simulations/compute',
              body: {
                'principal_minor': terms.principalMinor,
                'annual_rate_bps': terms.annualRateBps,
                'insurance_monthly_minor': terms.insuranceMonthlyMinor,
                'term_months': terms.termMonths,
                'upfront_fees_minor': terms.upfrontFeesMinor,
                'property_price_minor': ?terms.propertyPriceMinor,
                'down_payment_minor': ?terms.downPaymentMinor,
                'include_existing_loans': includeExistingLoans,
              },
            )
            as Map<String, dynamic>;
    return _parseResult(json);
  }

  /// The slice of the loans summary the HCSF reading needs.
  Future<HouseholdContext> household() async {
    final json =
        await _apiClient.get('/mortgages/summary') as Map<String, dynamic>;
    return HouseholdContext(
      existingChargeMinor: json['monthly_charge_minor'] as int,
      monthlyIncomeMinor: json['monthly_income_minor'] as int?,
      incomeSource: IncomeSource.fromWire(json['income_source'] as String),
      currency: json['currency'] as String,
    );
  }

  /// Declares the monthly income the debt ratio runs on.
  Future<void> declareIncome(int monthlyIncomeMinor) => _apiClient.patch(
    '/settings',
    body: {'declared_monthly_income_minor': monthlyIncomeMinor},
  );

  SavedSimulation _parseSaved(Map<String, dynamic> json) => SavedSimulation(
    id: json['id'] as String,
    label: json['label'] as String,
    terms: SimulationTerms(
      principalMinor: json['principal_minor'] as int,
      annualRateBps: json['annual_rate_bps'] as int,
      insuranceMonthlyMinor: json['insurance_monthly_minor'] as int,
      termMonths: json['term_months'] as int,
      upfrontFeesMinor: json['upfront_fees_minor'] as int,
      propertyPriceMinor: json['property_price_minor'] as int,
      downPaymentMinor: json['down_payment_minor'] as int,
    ),
    currency: json['currency'] as String,
  );

  SimulationResult _parseResult(Map<String, dynamic> json) {
    final hcsf = json['hcsf'] as Map<String, dynamic>;
    return SimulationResult(
      monthlyPaymentMinor: json['monthly_payment_minor'] as int,
      totalInstalmentMinor: json['total_instalment_minor'] as int,
      totalInterestMinor: json['total_interest_minor'] as int,
      totalInsuranceMinor: json['total_insurance_minor'] as int,
      totalCostMinor: json['total_cost_minor'] as int,
      costOverPriceBps: json['cost_over_price_bps'] as int?,
      taegBps: json['taeg_bps'] as int,
      yearly: [
        for (final row
            in (json['yearly'] as List<dynamic>).cast<Map<String, dynamic>>())
          SimulationYear(
            year: row['year'] as int,
            instalmentMinor: row['instalment_minor'] as int,
            interestMinor: row['interest_minor'] as int,
            principalMinor: row['principal_minor'] as int,
            insuranceMinor: row['insurance_minor'] as int,
            outstandingAfterMinor: row['outstanding_after_minor'] as int,
          ),
      ],
      debtRatioBps: json['debt_ratio_bps'] as int?,
      hcsf: HcsfReading(
        withinRatio: hcsf['within_ratio'] as bool?,
        withinTerm: hcsf['within_term'] as bool,
        limitBps: hcsf['limit_bps'] as int,
        maxTermMonths: hcsf['max_term_months'] as int,
      ),
      maxBorrowableMinor: json['max_borrowable_minor'] as int?,
      availableInstalmentMinor: json['available_instalment_minor'] as int?,
      currency: json['currency'] as String,
    );
  }
}

final simulationsRepositoryProvider = Provider<SimulationsRepository>((ref) {
  return SimulationsRepository(ref.watch(apiClientProvider));
});
