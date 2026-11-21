import 'package:bastide/features/placements/application/placements_controller.dart';
import 'package:bastide/features/placements/domain/investment.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// One placement. Every figure is invented; the derived ones are computed
/// the way the backend derives them, so a fixture can't contradict itself.
Investment testInvestment({
  String id = 'i1',
  String name = 'PEA',
  String institution = 'Courtier Nord',
  Envelope envelope = Envelope.pea,
  DateTime? openedOn,
  DateTime? closedOn,
  int paidInMinor = 2700000,
  int withdrawnMinor = 0,
  int? lastValueMinor = 3184000,
  DateTime? lastValuedOn,
  bool valueStale = false,
  int ageMonths = 38,
  int? paymentCeilingMinor = 15000000,
  int? milestoneYears = 5,
  DateTime? milestoneOn,
  bool milestoneReached = false,
  int linkedMovementCount = 0,
}) {
  final net = paidInMinor + withdrawnMinor;
  final gain = lastValueMinor == null || closedOn != null
      ? null
      : lastValueMinor - net;
  return Investment(
    id: id,
    name: name,
    institution: institution,
    envelope: envelope,
    openedOn: openedOn ?? DateTime(2023, 3, 14),
    closedOn: closedOn,
    currency: 'EUR',
    paidInMinor: paidInMinor,
    withdrawnMinor: withdrawnMinor,
    netPaymentsMinor: net,
    lastValueMinor: lastValueMinor,
    lastValuedOn: lastValueMinor == null
        ? null
        : (lastValuedOn ?? DateTime(2026, 4, 30)),
    unrealisedGainMinor: gain,
    gainBps: gain == null || net <= 0 ? null : (gain * 10000 / net).round(),
    valueStale: valueStale,
    ageMonths: ageMonths,
    paymentCeilingMinor: paymentCeilingMinor,
    milestoneYears: milestoneYears,
    milestoneOn: milestoneYears == null
        ? null
        : (milestoneOn ?? DateTime(2028, 3, 14)),
    milestoneReached: milestoneReached,
    movementCount: 2,
    linkedMovementCount: linkedMovementCount,
  );
}

/// The three placements of the mockup's shape, with invented figures: a
/// PEA, a life insurance policy past its milestone, and a stale PEE.
List<Investment> specInvestments() => [
  testInvestment(),
  testInvestment(
    id: 'i2',
    name: 'Assurance vie Horizon',
    institution: 'Assureur Sud',
    envelope: Envelope.lifeInsurance,
    openedOn: DateTime(2017, 9, 2),
    paidInMinor: 1450000,
    lastValueMinor: 1678000,
    lastValuedOn: DateTime(2026, 3, 31),
    ageMonths: 104,
    paymentCeilingMinor: null,
    milestoneYears: 8,
    milestoneOn: DateTime(2025, 9, 2),
    milestoneReached: true,
  ),
  testInvestment(
    id: 'i3',
    name: 'PEE Entreprise',
    institution: 'Gestion Est',
    envelope: Envelope.pee,
    openedOn: DateTime(2022, 1, 10),
    paidInMinor: 520000,
    lastValueMinor: 561500,
    lastValuedOn: DateTime(2025, 12, 31),
    valueStale: true,
    ageMonths: 52,
    paymentCeilingMinor: null,
    milestoneOn: DateTime(2027, 1, 10),
  ),
];

InvestmentSummary testInvestmentSummary({
  int openCount = 3,
  int declaredValueMinor = 5423500,
  int netPaymentsMinor = 4670000,
  int unrealisedGainMinor = 753500,
  int? gainBps = 1613,
  int valuedCount = 3,
  int staleCount = 1,
  DateTime? lastValuedOn,
}) => InvestmentSummary(
  openCount: openCount,
  closedCount: 0,
  declaredValueMinor: declaredValueMinor,
  netPaymentsMinor: netPaymentsMinor,
  unrealisedGainMinor: unrealisedGainMinor,
  gainBps: gainBps,
  valuedCount: valuedCount,
  staleCount: staleCount,
  lastValuedOn: valuedCount == 0
      ? null
      : (lastValuedOn ?? DateTime(2026, 4, 30)),
  currency: 'EUR',
);

/// The history of [testInvestment]: two payments and two declared values.
InvestmentDetail testDetail({Investment? investment}) {
  final inv = investment ?? testInvestment();
  return InvestmentDetail(
    investment: inv,
    movements: [
      InvestmentMovement(
        id: 'm2',
        investmentId: inv.id,
        occurredOn: DateTime(2026, 4, 5),
        amountMinor: 50000,
        note: null,
        transactionId: 't1',
      ),
      InvestmentMovement(
        id: 'm1',
        investmentId: inv.id,
        occurredOn: DateTime(2023, 3, 14),
        amountMinor: 2650000,
        note: 'Ouverture',
        transactionId: null,
      ),
    ],
    valuations: inv.lastValueMinor == null
        ? const []
        : [
            InvestmentValuation(
              id: 'v2',
              investmentId: inv.id,
              valuedOn: DateTime(2026, 4, 30),
              valueMinor: 3184000,
              note: null,
            ),
            InvestmentValuation(
              id: 'v1',
              investmentId: inv.id,
              valuedOn: DateTime(2026, 1, 31),
              valueMinor: 3060000,
              note: null,
            ),
          ],
  );
}

/// A no-network [PlacementsController] for widget tests: a fixed state,
/// and a record of the writes the panel attempted.
class FakePlacementsController extends PlacementsController {
  FakePlacementsController({
    this.investments = const [],
    InvestmentSummary? summary,
    this.loadError,
  }) : summary = summary ?? testInvestmentSummary();

  final List<Investment> investments;
  final InvestmentSummary summary;
  final Object? loadError;

  final createCalls = <Map<String, Object?>>[];
  final valuationCalls = <(String, DateTime, int, String?)>[];
  final movementCalls = <(String, DateTime, int, String?)>[];
  final closeCalls = <(String, DateTime, int)>[];
  final deleteCalls = <String>[];
  Object? errorOnWrite;

  @override
  Future<PlacementsState> build() async {
    if (loadError != null) throw loadError!;
    return PlacementsState(investments: investments, summary: summary);
  }

  @override
  Future<InvestmentDetail> create({
    required String name,
    required String institution,
    required Envelope envelope,
    required DateTime openedOn,
    int? initialPaymentsMinor,
    int? initialValueMinor,
  }) async {
    if (errorOnWrite != null) throw errorOnWrite!;
    createCalls.add({
      'name': name,
      'institution': institution,
      'envelope': envelope,
      'opened_on': openedOn,
      'payments': initialPaymentsMinor,
      'value': initialValueMinor,
    });
    return testDetail();
  }

  @override
  Future<void> addValuation(
    String id, {
    required DateTime valuedOn,
    required int valueMinor,
    String? note,
  }) async {
    if (errorOnWrite != null) throw errorOnWrite!;
    valuationCalls.add((id, valuedOn, valueMinor, note));
  }

  @override
  Future<void> addMovement(
    String id, {
    required DateTime occurredOn,
    required int amountMinor,
    String? note,
    String? transactionId,
  }) async {
    if (errorOnWrite != null) throw errorOnWrite!;
    movementCalls.add((id, occurredOn, amountMinor, note));
  }

  @override
  Future<void> close(
    String id, {
    required DateTime closedOn,
    required int finalAmountMinor,
  }) async {
    closeCalls.add((id, closedOn, finalAmountMinor));
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls.add(id);
  }
}

/// The panel's providers, overridden with [controller] and fixed details.
List<Override> placementsOverrides(
  FakePlacementsController controller, {
  Map<String, InvestmentDetail> details = const {},
}) => [
  placementsControllerProvider.overrideWith(() => controller),
  placementDetailProvider.overrideWith(
    (ref, id) async =>
        details[id] ??
        testDetail(
          investment: controller.investments.firstWhere((i) => i.id == id),
        ),
  ),
  linkCandidatesProvider.overrideWith((ref, query) async => const []),
];
