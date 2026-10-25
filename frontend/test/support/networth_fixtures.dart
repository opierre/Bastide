import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/domain/networth_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The frame's composition (`15-synthese.md` §Row 2): two account types and
/// two property kinds, shares summing to 10000.
const frameComposition = [
  CompositionEntry(
    group: CompositionGroup.account,
    key: 'checking',
    amountMinor: 1180000,
    shareBps: 230,
  ),
  CompositionEntry(
    group: CompositionGroup.account,
    key: 'savings',
    amountMinor: 1250000,
    shareBps: 240,
  ),
  CompositionEntry(
    group: CompositionGroup.property,
    key: 'primary_residence',
    amountMinor: 42000000,
    shareBps: 8130,
  ),
  CompositionEntry(
    group: CompositionGroup.property,
    key: 'rental',
    amountMinor: 7250000,
    shareBps: 1400,
  ),
];

/// Twelve closed months, June 2025 → May 2026, ending on the frame's figure.
List<NetWorthPoint> frameSeries() => [
  for (var index = 0; index < 12; index++)
    NetWorthPoint(
      month: DateTime(2025, 6 + index),
      netWorthMinor: index == 11 ? 28267079 : 26800000 + index * 120000,
    ),
];

/// Frame ① / ⑥: accounts, two properties, two loans.
NetWorthSummary testNetworthSummary({
  int accountsMinor = 2430000,
  int propertiesMinor = 49250000,
  int mortgagesMinor = 23412921,
  int netWorthMinor = 28267079,
  List<CompositionEntry> composition = frameComposition,
  int? monthDeltaMinor = 147778,
  List<NetWorthPoint>? series,
  bool propertyValuesHeldFlat = true,
  DateTime? valuedOnOldest,
  int activeLoanCount = 2,
}) => NetWorthSummary(
  accountsMinor: accountsMinor,
  propertiesMinor: propertiesMinor,
  mortgagesMinor: mortgagesMinor,
  netWorthMinor: netWorthMinor,
  composition: composition,
  monthDeltaMinor: monthDeltaMinor,
  series: series ?? frameSeries(),
  propertyValuesHeldFlat: propertyValuesHeldFlat,
  valuedOnOldest: propertyValuesHeldFlat
      ? (valuedOnOldest ?? DateTime(2026, 1, 12))
      : null,
  activeLoanCount: activeLoanCount,
  currency: 'EUR',
);

/// Frame ④: the same accounts and loans with no property — legitimately
/// negative.
NetWorthSummary testNoPropertySummary() => testNetworthSummary(
  propertiesMinor: 0,
  netWorthMinor: -20982921,
  composition: const [
    CompositionEntry(
      group: CompositionGroup.account,
      key: 'checking',
      amountMinor: 1180000,
      shareBps: 4856,
    ),
    CompositionEntry(
      group: CompositionGroup.account,
      key: 'savings',
      amountMinor: 1250000,
      shareBps: 5144,
    ),
  ],
  propertyValuesHeldFlat: false,
);

/// Frame ⑤: nothing at all.
NetWorthSummary testEmptySummary() => testNetworthSummary(
  accountsMinor: 0,
  propertiesMinor: 0,
  mortgagesMinor: 0,
  netWorthMinor: 0,
  composition: const [],
  monthDeltaMinor: null,
  series: const [],
  propertyValuesHeldFlat: false,
  activeLoanCount: 0,
);

/// A no-network [NetworthController] double for widget tests.
class FakeNetworthController extends NetworthController {
  FakeNetworthController({NetWorthSummary? summary, this.loadError})
    : summary = summary ?? testNetworthSummary();

  final NetWorthSummary summary;
  final Object? loadError;

  @override
  Future<NetWorthSummary> build() async {
    if (loadError != null) throw loadError!;
    return summary;
  }
}

/// Thirty closed months, Dec 2023 → May 2026: the first eighteen declared,
/// the last twelve imported — the shape a user with a year of statements and
/// a notebook of older totals has.
List<NetWorthPoint> longSeries() => [
  for (var index = 0; index < 30; index++)
    NetWorthPoint(
      month: DateTime(2023, 12 + index),
      netWorthMinor: 25000000 + index * 100000,
      declared: index < 18,
    ),
];

/// A no-network [DeclaredBalancesController] double that records writes.
class FakeDeclaredBalancesController extends DeclaredBalancesController {
  FakeDeclaredBalancesController({
    List<DeclaredBalance>? entries,
    this.writeError,
  }) : entries = entries ?? const [];

  List<DeclaredBalance> entries;
  final Object? writeError;
  final declaredWrites = <(DateTime, int)>[];
  final removed = <DateTime>[];

  @override
  Future<List<DeclaredBalance>> build() async => entries;

  @override
  Future<void> declare(DateTime month, int amountMinor) async {
    if (writeError != null) throw writeError!;
    declaredWrites.add((month, amountMinor));
    entries = [
      for (final entry in entries)
        if (entry.month != month) entry,
      DeclaredBalance(
        month: month,
        amountMinor: amountMinor,
        currency: 'EUR',
        superseded: false,
      ),
    ]..sort((a, b) => a.month.compareTo(b.month));
    state = AsyncValue.data(entries);
  }

  @override
  Future<void> remove(DateTime month) async {
    removed.add(month);
    entries = [
      for (final entry in entries)
        if (entry.month != month) entry,
    ];
    state = AsyncValue.data(entries);
  }
}
