import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// A basis-point figure printed as the locale's percent — « 30,8 % », « 3.25% ».
///
/// Display formatting only: the value is the API's, and the division is the
/// unit change a percent sign implies, not a computation about the loan.
String formatBps(int bps, String locale, {int digits = 1}) {
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = digits
    ..maximumFractionDigits = digits;
  return format.format(bps / 10000);
}

/// A nominal rate, always to the hundredth the user typed it in.
String formatRate(int bps, String locale) => formatBps(bps, locale, digits: 2);

/// Reads a typed percent as basis points — « 3,25 » → 325.
///
/// The one place a rate changes unit. Done on the digits rather than through a
/// double, so 3,45 can never come out as 344. Accepts a comma or a point, at
/// most two decimals.
int? parseRateBps(String raw) {
  final match = RegExp(r'^\s*(\d{1,3})(?:[.,](\d{0,2}))?\s*$').firstMatch(raw);
  if (match == null) return null;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return int.parse(match.group(1)!) * 100 + int.parse(fraction);
}

/// A term in whole years when it is one — « 25 ans » — else in months.
String termLabel(AppLocalizations l10n, int months) => months % 12 == 0
    ? l10n.simulatorYears(months ~/ 12)
    : l10n.simulatorMonths(months);

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

/// The 16 px uppercase marker pill (`00` §Patrimoine additions): iris for
/// « INDICATIF » and « EN COURS », gray for « DÉRIVÉ ».
class SimulatorMarkerPill extends StatelessWidget {
  const SimulatorMarkerPill({
    super.key,
    required this.label,
    this.neutral = false,
  });

  final String label;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: neutral ? AppColors.surfaceHover : AppColors.irisSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.geist,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          height: 1,
          color: neutral ? AppColors.textSecondary : AppColors.iris,
        ),
      ),
    );
  }
}
