import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/investment.dart';

final _isoDate = DateFormat('yyyy-MM-dd');

/// Calls the `/investments` endpoints and maps the wire JSON to domain
/// models. The only place in this feature that knows the response shapes.
class PlacementsRepository {
  PlacementsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Every placement, open ones first.
  Future<List<Investment>> list() async {
    final json = await _apiClient.get('/investments') as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>())
        _parseInvestment(entry),
    ];
  }

  Future<InvestmentSummary> summary() async {
    final json =
        await _apiClient.get('/investments/summary') as Map<String, dynamic>;
    return InvestmentSummary(
      openCount: json['open_count'] as int,
      closedCount: json['closed_count'] as int,
      declaredValueMinor: json['declared_value_minor'] as int,
      netPaymentsMinor: json['net_payments_minor'] as int,
      unrealisedGainMinor: json['unrealised_gain_minor'] as int,
      gainBps: json['gain_bps'] as int?,
      valuedCount: json['valued_count'] as int,
      staleCount: json['stale_count'] as int,
      lastValuedOn: _dateOrNull(json['last_valued_on']),
      currency: json['currency'] as String,
    );
  }

  Future<InvestmentDetail> detail(String id) async =>
      _parseDetail(await _apiClient.get('/investments/$id'));

  /// Creates a placement; [initialPaymentsMinor] becomes one movement at the
  /// opening date, [initialValueMinor] one declared value today.
  Future<InvestmentDetail> create({
    required String name,
    required String institution,
    required Envelope envelope,
    required DateTime openedOn,
    int? initialPaymentsMinor,
    int? initialValueMinor,
  }) async => _parseDetail(
    await _apiClient.post(
      '/investments',
      body: {
        'name': name,
        'institution': institution,
        'envelope': envelope.wireValue,
        'opened_on': _isoDate.format(openedOn),
        'initial_payments_minor': ?initialPaymentsMinor,
        'initial_value_minor': ?initialValueMinor,
      },
    ),
  );

  Future<InvestmentDetail> update(
    String id, {
    required String name,
    required String institution,
    required Envelope envelope,
    required DateTime openedOn,
  }) async => _parseDetail(
    await _apiClient.patch(
      '/investments/$id',
      body: {
        'name': name,
        'institution': institution,
        'envelope': envelope.wireValue,
        'opened_on': _isoDate.format(openedOn),
      },
    ),
  );

  Future<void> delete(String id) => _apiClient.delete('/investments/$id');

  Future<InvestmentDetail> close(
    String id, {
    required DateTime closedOn,
    required int finalAmountMinor,
  }) async => _parseDetail(
    await _apiClient.post(
      '/investments/$id/close',
      body: {
        'closed_on': _isoDate.format(closedOn),
        'final_amount_minor': finalAmountMinor,
      },
    ),
  );

  Future<InvestmentDetail> reopen(String id) async =>
      _parseDetail(await _apiClient.post('/investments/$id/reopen'));

  /// Imported transactions of the opposite amount near [on], for the
  /// « Transaction liée » select.
  Future<List<LinkCandidate>> linkCandidates(
    String id, {
    required int amountMinor,
    required DateTime on,
    String? movementId,
  }) async {
    final json =
        await _apiClient.get(
              '/investments/$id/link-candidates',
              query: {
                'amount_minor': '$amountMinor',
                'on': _isoDate.format(on),
                'movement_id': ?movementId,
              },
            )
            as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>())
        LinkCandidate(
          transactionId: entry['transaction_id'] as String,
          accountName: entry['account_name'] as String,
          bookedDate: DateTime.parse(entry['booked_date'] as String),
          amountMinor: entry['amount_minor'] as int,
          currency: entry['currency'] as String,
          description: entry['description'] as String,
        ),
    ];
  }

  Future<void> addMovement(
    String id, {
    required DateTime occurredOn,
    required int amountMinor,
    String? note,
    String? transactionId,
  }) => _apiClient.post(
    '/investments/$id/movements',
    body: {
      'occurred_on': _isoDate.format(occurredOn),
      'amount_minor': amountMinor,
      'note': ?note,
      'transaction_id': ?transactionId,
    },
  );

  /// Patches every field; a `null` [note] or [transactionId] clears it.
  Future<void> updateMovement(
    String id,
    String movementId, {
    required DateTime occurredOn,
    required int amountMinor,
    String? note,
    String? transactionId,
  }) => _apiClient.patch(
    '/investments/$id/movements/$movementId',
    body: {
      'occurred_on': _isoDate.format(occurredOn),
      'amount_minor': amountMinor,
      'note': note,
      'transaction_id': transactionId,
    },
  );

  Future<void> deleteMovement(String id, String movementId) =>
      _apiClient.delete('/investments/$id/movements/$movementId');

  Future<void> addValuation(
    String id, {
    required DateTime valuedOn,
    required int valueMinor,
    String? note,
  }) => _apiClient.post(
    '/investments/$id/valuations',
    body: {
      'valued_on': _isoDate.format(valuedOn),
      'value_minor': valueMinor,
      'note': ?note,
    },
  );

  /// Patches every field; a `null` [note] clears it.
  Future<void> updateValuation(
    String id,
    String valuationId, {
    required DateTime valuedOn,
    required int valueMinor,
    String? note,
  }) => _apiClient.patch(
    '/investments/$id/valuations/$valuationId',
    body: {
      'valued_on': _isoDate.format(valuedOn),
      'value_minor': valueMinor,
      'note': note,
    },
  );

  Future<void> deleteValuation(String id, String valuationId) =>
      _apiClient.delete('/investments/$id/valuations/$valuationId');

  static DateTime? _dateOrNull(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  static Investment _parseInvestment(Map<String, dynamic> json) => Investment(
    id: json['id'] as String,
    name: json['name'] as String,
    institution: json['institution'] as String,
    envelope: Envelope.fromWire(json['envelope'] as String),
    openedOn: DateTime.parse(json['opened_on'] as String),
    closedOn: _dateOrNull(json['closed_on']),
    currency: json['currency'] as String,
    paidInMinor: json['paid_in_minor'] as int,
    withdrawnMinor: json['withdrawn_minor'] as int,
    netPaymentsMinor: json['net_payments_minor'] as int,
    lastValueMinor: json['last_value_minor'] as int?,
    lastValuedOn: _dateOrNull(json['last_valued_on']),
    unrealisedGainMinor: json['unrealised_gain_minor'] as int?,
    gainBps: json['gain_bps'] as int?,
    valueStale: json['value_stale'] as bool,
    ageMonths: json['age_months'] as int,
    paymentCeilingMinor: json['payment_ceiling_minor'] as int?,
    milestoneYears: json['milestone_years'] as int?,
    milestoneOn: _dateOrNull(json['milestone_on']),
    milestoneReached: json['milestone_reached'] as bool,
    movementCount: json['movement_count'] as int,
    linkedMovementCount: json['linked_movement_count'] as int,
  );

  static InvestmentDetail _parseDetail(Object? raw) {
    final json = raw as Map<String, dynamic>;
    return InvestmentDetail(
      investment: _parseInvestment(json),
      movements: [
        for (final entry
            in (json['movements'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
          InvestmentMovement(
            id: entry['id'] as String,
            investmentId: entry['investment_id'] as String,
            occurredOn: DateTime.parse(entry['occurred_on'] as String),
            amountMinor: entry['amount_minor'] as int,
            note: entry['note'] as String?,
            transactionId: entry['transaction_id'] as String?,
          ),
      ],
      valuations: [
        for (final entry
            in (json['valuations'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
          InvestmentValuation(
            id: entry['id'] as String,
            investmentId: entry['investment_id'] as String,
            valuedOn: DateTime.parse(entry['valued_on'] as String),
            valueMinor: entry['value_minor'] as int,
            note: entry['note'] as String?,
          ),
      ],
    );
  }
}

final placementsRepositoryProvider = Provider<PlacementsRepository>((ref) {
  return PlacementsRepository(ref.watch(apiClientProvider));
});
