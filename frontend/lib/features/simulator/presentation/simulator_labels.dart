import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';

/// The form field a refused compute belongs to, so its message lands under the
/// number the user has to change.
enum SimulatorErrorField { rate, fees, none }

SimulatorErrorField simulatorErrorField(Object? error) {
  if (error is! ApiFailure) return SimulatorErrorField.none;
  return switch (error.code) {
    // The instalment is fixed by amount, rate and term together; the rate is
    // the field a user most often mistypes, so the explanation sits there.
    'MORTGAGE_NON_AMORTIZING' => SimulatorErrorField.rate,
    'MORTGAGE_FEES_EXCEED_PRINCIPAL' => SimulatorErrorField.fees,
    _ => SimulatorErrorField.none,
  };
}

/// Maps the simulator's stable error `code`s (see
/// `backend/app/features/mortgages/simulations_service.py`) to a message.
String localizeSimulatorError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'MORTGAGE_NON_AMORTIZING':
        return l10n.simulatorErrorNonAmortizing;
      case 'MORTGAGE_FEES_EXCEED_PRINCIPAL':
        return l10n.simulatorErrorFeesExceed;
      case 'SIMULATION_LIMIT_REACHED':
        return l10n.simulatorErrorLimitReached;
      case 'SIMULATION_NOT_FOUND':
        return l10n.simulatorErrorNotFound;
      case 'VALIDATION_ERROR':
        return l10n.simulatorErrorValidation;
    }
  }
  return l10n.simulatorErrorGeneric;
}
