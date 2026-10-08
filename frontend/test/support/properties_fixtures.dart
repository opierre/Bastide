import 'package:bastide/features/properties/application/properties_controller.dart';
import 'package:bastide/features/properties/domain/property.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The frame's résidence principale (`15-synthese.md` §Biens, card 1).
Property testProperty({
  String id = 'p1',
  String label = 'Appartement Lyon 3e',
  PropertyKind kind = PropertyKind.primaryResidence,
  int marketValueMinor = 42000000,
  DateTime? valuedOn,
  int ownershipBps = 10000,
  int? acquisitionPriceMinor = 38500000,
  DateTime? acquiredOn,
  bool archived = false,
  int userShareValueMinor = 42000000,
  int? acquisitionDeltaMinor = 3500000,
}) => Property(
  id: id,
  label: label,
  kind: kind,
  marketValueMinor: marketValueMinor,
  valuedOn: valuedOn ?? DateTime(2026, 1, 12),
  ownershipBps: ownershipBps,
  acquisitionPriceMinor: acquisitionPriceMinor,
  acquiredOn: acquiredOn ?? DateTime(2023, 9, 1),
  archived: archived,
  currency: 'EUR',
  userShareValueMinor: userShareValueMinor,
  acquisitionDeltaMinor: acquisitionDeltaMinor,
);

/// The frame's locatif held at 50 % (`15-synthese.md` §Biens, card 2).
Property testStudio({bool archived = false}) => testProperty(
  id: 'p2',
  label: 'Studio Villeurbanne',
  kind: PropertyKind.rental,
  marketValueMinor: 14500000,
  valuedOn: DateTime(2026, 3, 5),
  ownershipBps: 5000,
  acquisitionPriceMinor: 13200000,
  acquiredOn: DateTime(2021, 6, 14),
  archived: archived,
  userShareValueMinor: 7250000,
  acquisitionDeltaMinor: 650000,
);

/// A no-network [PropertiesController] double for widget tests: fixed lists,
/// plus a record of the writes the panel attempted.
class FakePropertiesController extends PropertiesController {
  FakePropertiesController({
    this.initialProperties = const [],
    this.initialArchived = const [],
    this.loadError,
  });

  final List<Property> initialProperties;
  final List<Property> initialArchived;
  final Object? loadError;

  final createCalls = <PropertyDraft>[];
  final updateCalls = <(String, PropertyDraft)>[];
  final revalueCalls = <(String, int, DateTime)>[];
  final archiveCalls = <String>[];
  final unarchiveCalls = <String>[];
  Object? errorOnSave;

  @override
  Future<PropertiesState> build() async {
    if (loadError != null) throw loadError!;
    return PropertiesState(
      properties: initialProperties,
      archived: initialArchived,
    );
  }

  @override
  Future<Property> create(PropertyDraft draft) async {
    if (errorOnSave != null) throw errorOnSave!;
    createCalls.add(draft);
    return testProperty();
  }

  @override
  Future<Property> updateProperty(
    String propertyId,
    PropertyDraft draft,
  ) async {
    if (errorOnSave != null) throw errorOnSave!;
    updateCalls.add((propertyId, draft));
    return testProperty(id: propertyId);
  }

  @override
  Future<Property> revalue(
    String propertyId, {
    required int marketValueMinor,
    required DateTime valuedOn,
  }) async {
    if (errorOnSave != null) throw errorOnSave!;
    revalueCalls.add((propertyId, marketValueMinor, valuedOn));
    return testProperty(id: propertyId);
  }

  @override
  Future<void> archive(String propertyId) async {
    archiveCalls.add(propertyId);
    final current = state.value;
    if (current == null) return;
    // Flagged the way the server returns an archived property, so its card
    // offers « Désarchiver » rather than the live menu.
    final moved = [
      for (final p in current.properties)
        if (p.id == propertyId)
          Property(
            id: p.id,
            label: p.label,
            kind: p.kind,
            marketValueMinor: p.marketValueMinor,
            valuedOn: p.valuedOn,
            ownershipBps: p.ownershipBps,
            acquisitionPriceMinor: p.acquisitionPriceMinor,
            acquiredOn: p.acquiredOn,
            archived: true,
            currency: p.currency,
            userShareValueMinor: p.userShareValueMinor,
            acquisitionDeltaMinor: p.acquisitionDeltaMinor,
          ),
    ];
    state = AsyncValue.data(
      current.copyWith(
        properties: [
          for (final property in current.properties)
            if (property.id != propertyId) property,
        ],
        archived: [...current.archived, ...moved],
      ),
    );
  }

  @override
  Future<void> unarchive(String propertyId) async {
    unarchiveCalls.add(propertyId);
  }
}
