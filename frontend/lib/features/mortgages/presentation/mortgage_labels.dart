import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/date_display.dart';
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

/// « 1 juin 2026 » — a due date in a summary line or a caption.
DayMonthFormat mortgageLongDateFormat(String locale) =>
    DayMonthFormat.yMMMMd(locale);

/// « 1 sept. 2023 » — a date in a table cell or a secondary line.
DayMonthFormat mortgageDateFormat(String locale) =>
    DayMonthFormat.yMMMd(locale);

/// « août 2048 » — the month a loan ends, in the loans table.
DateFormat mortgageMonthFormat(String locale) => DateFormat.yMMM(locale);

/// « mai 2026 » — today's annotation on the trajectory chart.
DateFormat mortgageLongMonthFormat(String locale) => DateFormat.yMMMM(locale);

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
