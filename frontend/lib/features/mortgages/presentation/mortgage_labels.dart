import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/mortgage.dart';

/// The ARB label of a credit product — the backend stores the machine value only.
String mortgageKindLabel(AppLocalizations l10n, MortgageKind kind) =>
    switch (kind) {
      MortgageKind.mortgage => l10n.mortgageKindMortgage,
      MortgageKind.works => l10n.mortgageKindWorks,
      MortgageKind.consumer => l10n.mortgageKindConsumer,
      MortgageKind.auto => l10n.mortgageKindAuto,
    };

String repaymentTypeLabel(AppLocalizations l10n, RepaymentType type) =>
    switch (type) {
      RepaymentType.constantPayment => l10n.mortgageRepaymentConstant,
      RepaymentType.interestOnly => l10n.mortgageRepaymentInterestOnly,
    };

/// « 01/06/2026 » — the locale's short numeric date.
DateFormat mortgageDateFormat(String locale) => DateFormat.yMd(locale);

/// « 02/2030 » — a month on the trajectory chart's end markers.
DateFormat mortgageMonthFormat(String locale) => DateFormat.yM(locale);

/// A basis-point figure printed as the locale's percent — « 32,7 % », « 3.45% ».
///
/// Display formatting only: the value is the API's, and the division is the
/// unit change a percent sign implies, not a computation about the loan.
String formatBps(int bps, String locale, {int digits = 1}) {
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = digits
    ..maximumFractionDigits = digits;
  return format.format(bps / 10000);
}

/// The form field a refused write belongs to, so its message lands under the
/// number the user has to change rather than in a toast.
enum MortgageErrorField { rate, fees, property, none }

MortgageErrorField mortgageErrorField(Object? error) {
  if (error is! ApiFailure) return MortgageErrorField.none;
  return switch (error.code) {
    // The instalment is fixed by principal, rate and term together; the rate is
    // the field a user most often mistypes, so the explanation sits there.
    'MORTGAGE_NON_AMORTIZING' => MortgageErrorField.rate,
    'MORTGAGE_FEES_EXCEED_PRINCIPAL' => MortgageErrorField.fees,
    'MORTGAGE_PROPERTY_INVALID' => MortgageErrorField.property,
    _ => MortgageErrorField.none,
  };
}

/// Maps the mortgages feature's stable error `code`s (see
/// `backend/app/features/mortgages/service.py`) to a localized message.
String localizeMortgageError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'MORTGAGE_NON_AMORTIZING':
        return l10n.mortgageErrorNonAmortizing;
      case 'MORTGAGE_FEES_EXCEED_PRINCIPAL':
        return l10n.mortgageErrorFeesExceed;
      case 'MORTGAGE_PROPERTY_INVALID':
        return l10n.mortgageErrorPropertyInvalid;
      case 'MORTGAGE_NOT_FOUND':
        return l10n.mortgageErrorNotFound;
      case 'VALIDATION_ERROR':
        return l10n.mortgageErrorValidation;
    }
  }
  return l10n.mortgageErrorGeneric;
}
