import 'package:flutter/foundation.dart';

/// The nature of a declared property (`PROJECT.md` §4c). A label only: no
/// computation reads it.
enum PropertyKind {
  primaryResidence('primary_residence'),
  rental('rental'),
  secondary('secondary'),
  other('other');

  const PropertyKind(this.wireValue);

  final String wireValue;

  static PropertyKind fromWire(String value) => values.firstWhere(
    (kind) => kind.wireValue == value,
    orElse: () => PropertyKind.other,
  );
}

/// A whole property, in basis points of ownership.
const fullOwnershipBps = 10000;

/// A declared property with the two share figures the backend derives from it.
///
/// Declared, never observed: the app has no statement to read a property from,
/// so the value is exactly what the user typed on [valuedOn] — and the panel
/// says how old that is.
@immutable
class Property {
  const Property({
    required this.id,
    required this.label,
    required this.kind,
    required this.marketValueMinor,
    required this.valuedOn,
    required this.ownershipBps,
    required this.acquisitionPriceMinor,
    required this.acquiredOn,
    required this.archived,
    required this.currency,
    required this.userShareValueMinor,
    required this.acquisitionDeltaMinor,
  });

  final String id;
  final String label;
  final PropertyKind kind;
  final int marketValueMinor;
  final DateTime valuedOn;
  final int ownershipBps;
  final int? acquisitionPriceMinor;
  final DateTime? acquiredOn;
  final bool archived;
  final String currency;

  /// The held share of the declared value — server-derived.
  final int userShareValueMinor;

  /// The held share less the held share of the acquisition price; `null`
  /// without a price. Server-derived.
  final int? acquisitionDeltaMinor;

  /// Below 100 %: the card and the composition say « part détenue ».
  bool get isPartlyOwned => ownershipBps < fullOwnershipBps;
}

/// The declared inputs of a property, as the form collects them. Ownership is
/// already in bps: the percent the user typed is converted at the form edge.
@immutable
class PropertyDraft {
  const PropertyDraft({
    required this.label,
    required this.kind,
    required this.marketValueMinor,
    required this.valuedOn,
    this.ownershipBps = fullOwnershipBps,
    this.acquisitionPriceMinor,
    this.acquiredOn,
  });

  final String label;
  final PropertyKind kind;
  final int marketValueMinor;
  final DateTime valuedOn;
  final int ownershipBps;

  /// `null` leaves the price unset — and, on a patch, leaves it alone: the API
  /// cannot clear it.
  final int? acquisitionPriceMinor;
  final DateTime? acquiredOn;
}

/// The form's live « part : … » preview of the held share, before anything is
/// saved.
///
/// Mirrors `held_share_minor` in `backend/app/features/properties/service.py`
/// (half-up, integers only) so the preview agrees with the figure the card
/// shows once saved. It is a preview only: every stored or aggregated share is
/// the server's.
int previewHeldShareMinor(int amountMinor, int ownershipBps) =>
    (2 * amountMinor * ownershipBps + fullOwnershipBps) ~/
    (2 * fullOwnershipBps);
