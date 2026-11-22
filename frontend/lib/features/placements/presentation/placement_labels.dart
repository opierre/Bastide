import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/date_display.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/investment.dart';

/// The envelope's name, from ARB.
String envelopeLabel(AppLocalizations l10n, Envelope envelope) =>
    switch (envelope) {
      Envelope.pea => l10n.placementEnvelopePea,
      Envelope.peaPme => l10n.placementEnvelopePeaPme,
      Envelope.lifeInsurance => l10n.placementEnvelopeLifeInsurance,
      Envelope.per => l10n.placementEnvelopePer,
      Envelope.pee => l10n.placementEnvelopePee,
      Envelope.securitiesAccount => l10n.placementEnvelopeSecuritiesAccount,
      Envelope.other => l10n.placementEnvelopeOther,
    };

/// Maps the placements feature's error `code`s
/// (`backend/app/features/placements/service.py`) to a localized message.
String localizePlacementError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    return switch (error.code) {
      'INVESTMENT_NOT_FOUND' => l10n.placementErrorNotFound,
      'INVESTMENT_MOVEMENT_NOT_FOUND' => l10n.placementErrorMovementNotFound,
      'INVESTMENT_VALUATION_NOT_FOUND' => l10n.placementErrorValuationNotFound,
      'INVESTMENT_DATE_IN_FUTURE' => l10n.placementErrorDateInFuture,
      'INVESTMENT_DATE_BEFORE_OPENING' => l10n.placementErrorDateBeforeOpening,
      'INVESTMENT_DATE_AFTER_CLOSING' => l10n.placementErrorDateAfterClosing,
      'INVESTMENT_ALREADY_CLOSED' => l10n.placementErrorAlreadyClosed,
      'INVESTMENT_NOT_CLOSED' => l10n.placementErrorNotClosed,
      'INVESTMENT_VALUATION_EXISTS' => l10n.placementErrorValuationExists,
      'INVESTMENT_LINKED_TRANSACTION_NOT_FOUND' =>
        l10n.placementErrorLinkNotFound,
      'INVESTMENT_TRANSACTION_ALREADY_LINKED' =>
        l10n.placementErrorAlreadyLinked,
      'VALIDATION_ERROR' => l10n.placementErrorValidation,
      _ => l10n.placementErrorGeneric,
    };
  }
  return l10n.placementErrorGeneric;
}

/// A money figure of this panel. Neutral everywhere (`00` §2.3): a gain
/// carries its sign, a value or a total only a minus.
String placementMoney(
  int amountMinor,
  String currency,
  String locale, {
  bool signed = false,
}) => formatAmount(
  amountMinor: amountMinor,
  currency: currency,
  locale: locale,
  showPositiveSign: signed,
);

/// « +17,9 % »: a share in bps, one decimal, always signed.
String gainPercentLabel(int bps, String locale) {
  final formatted = NumberFormat('0.0', locale).format(bps.abs() / 100);
  final sign = bps > 0
      ? '+'
      : bps < 0
      ? '−'
      : '';
  return '$sign$formatted %';
}

/// « 30 avr. 2026 »: a date as the panel prints it.
String placementDateLabel(String locale, DateTime date) =>
    DayMonthFormat.yMMMd(locale).format(date);

/// « mars 2023 »: the month of a date, in the locale's own case.
String placementMonthLabel(String locale, DateTime date) =>
    DateFormat.yMMMM(locale).format(date);

/// « 3 ans 2 mois », « 8 mois », « 2 ans ».
String placementAgeLabel(AppLocalizations l10n, int months) {
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return l10n.placementAgeMonths(rest);
  if (rest == 0) return l10n.placementAgeYears(years);
  return l10n.placementAgeBoth(
    l10n.placementAgeYears(years),
    l10n.placementAgeMonths(rest),
  );
}

/// The fiscal reading under the age repère, or `null` when the envelope has
/// none written (`17-placements.md` §Inspector 6). A PEA-PME follows the
/// PEA's rule.
String? milestoneCaption(AppLocalizations l10n, Envelope envelope) =>
    switch (envelope) {
      Envelope.pea || Envelope.peaPme => l10n.placementMilestonePea,
      Envelope.lifeInsurance => l10n.placementMilestoneLifeInsurance,
      _ => null,
    };
