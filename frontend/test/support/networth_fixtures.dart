import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/domain/networth_summary.dart';

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
