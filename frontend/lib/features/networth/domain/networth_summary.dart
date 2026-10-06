import 'package:flutter/foundation.dart';

/// Which side of the asset strip a composition slice belongs to.
enum CompositionGroup {
  account('account'),
  property('property');

  const CompositionGroup(this.wireValue);

  final String wireValue;

  static CompositionGroup fromWire(String value) =>
      values.firstWhere((group) => group.wireValue == value);
}

/// One slice of the assets: an account type or a property kind, with its
/// server-computed share of total assets in bps.
@immutable
class CompositionEntry {
  const CompositionEntry({
    required this.group,
    required this.key,
    required this.amountMinor,
    required this.shareBps,
  });

  final CompositionGroup group;

  /// The account `type` or the property `kind` wire value, labelled from ARB.
  final String key;
  final int amountMinor;
  final int shareBps;
}

/// Net worth at the end of one closed month.
@immutable
class NetWorthPoint {
  const NetWorthPoint({required this.month, required this.netWorthMinor});

  /// First day of the month.
  final DateTime month;
  final int netWorthMinor;
}

/// `GET /networth/summary`, plus the active loan count the Passif card names.
///
/// Every figure is derived server-side. The panel formats
/// them and adds nothing: not a percentage, not a delta, not a zero-filled month.
@immutable
class NetWorthSummary {
  const NetWorthSummary({
    required this.accountsMinor,
    required this.propertiesMinor,
    required this.mortgagesMinor,
    required this.netWorthMinor,
    required this.composition,
    required this.monthDeltaMinor,
    required this.series,
    required this.propertyValuesHeldFlat,
    required this.valuedOnOldest,
    required this.activeLoanCount,
    required this.currency,
  });

  final int accountsMinor;

  /// The Actif figure: the two asset parts the API returns, added. The API
  /// states net worth but not this total; nothing else is derived here.
  int get assetsMinor => accountsMinor + propertiesMinor;

  /// The held shares of the non-archived properties.
  final int propertiesMinor;

  /// Outstanding principal of the active loans.
  final int mortgagesMinor;
  final int netWorthMinor;
  final List<CompositionEntry> composition;

  /// The last two series points' difference; `null` with fewer than two.
  final int? monthDeltaMinor;

  /// Closed months only, oldest first. A month without data is absent.
  final List<NetWorthPoint> series;
  final bool propertyValuesHeldFlat;

  /// The oldest current estimate across properties — what the caveat names.
  final DateTime? valuedOnOldest;
  final int activeLoanCount;
  final String currency;

  /// Nothing to add up: no account, no property, no loan. The one case the
  /// panel drops its segmented control for a full empty state.
  bool get isEmpty => composition.isEmpty && activeLoanCount == 0;
}
