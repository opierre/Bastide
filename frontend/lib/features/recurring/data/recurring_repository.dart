import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../../categories/domain/category.dart';
import '../domain/recurring_series.dart';
import '../domain/recurring_summary.dart';

/// Calls the `/recurring` endpoints and maps the wire JSON to domain models.
/// The only place in this feature that knows the response shapes.
///
/// It also reads `/accounts` and `/categories`, for the creation form and the
/// row chips. Those are foreign resources but the affordances are *this*
/// panel's, so the calls stay here rather than reaching into another feature's
/// controller — the same arrangement the transactions repository uses for its
/// category picker. Only the shared [AppCategory] shape is reused; the accounts
/// response maps to this panel's own narrow [SeriesAccount].
class RecurringRepository {
  RecurringRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RecurringSeries>> list({SeriesStatus? status, String? accountId}) async {
    final json =
        await _apiClient.get(
              '/recurring',
              query: {
                if (status != null) 'status': status.wireValue,
                'account_id': ?accountId,
              },
            )
            as List<dynamic>;
    return json.map((entry) => _parseSeries(entry as Map<String, dynamic>)).toList();
  }

  Future<RecurringSummary> summary() async {
    final json = await _apiClient.get('/recurring/summary') as Map<String, dynamic>;
    return _parseSummary(json);
  }

  Future<SeriesDetail> detail(String seriesId) async {
    final json = await _apiClient.get('/recurring/$seriesId') as Map<String, dynamic>;
    return SeriesDetail(
      series: _parseSeries(json),
      occurrences: (json['occurrences'] as List<dynamic>)
          .map((entry) => _parseOccurrence(entry as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Runs a detection pass and reports what it created and refreshed.
  Future<DetectionResult> detect({String? accountId}) async {
    final json =
        await _apiClient.post('/recurring/detect', body: {'account_id': accountId})
            as Map<String, dynamic>;
    return DetectionResult(
      createdCount: json['created_count'] as int,
      updatedCount: json['updated_count'] as int,
    );
  }

  Future<RecurringSeries> create({
    required String label,
    required String accountId,
    required int expectedAmountMinor,
    required Cadence cadence,
    String? categoryId,
  }) async {
    final json =
        await _apiClient.post(
              '/recurring',
              body: {
                'label': label,
                'account_id': accountId,
                'expected_amount_minor': expectedAmountMinor,
                'cadence': cadence.wireValue,
                'category_id': ?categoryId,
              },
            )
            as Map<String, dynamic>;
    return _parseSeries(json);
  }

  /// Patches a series. Omitted fields are left alone — `null` is
  /// indistinguishable from absent on this API, so clearing a category is not
  /// expressible and the form does not offer it.
  Future<RecurringSeries> update(
    String seriesId, {
    String? label,
    String? categoryId,
    Cadence? cadence,
    int? expectedAmountMinor,
    SeriesStatus? status,
  }) async {
    final json =
        await _apiClient.patch(
              '/recurring/$seriesId',
              body: {
                'label': ?label,
                'category_id': ?categoryId,
                if (cadence != null) 'cadence': cadence.wireValue,
                'expected_amount_minor': ?expectedAmountMinor,
                if (status != null) 'status': status.wireValue,
              },
            )
            as Map<String, dynamic>;
    return _parseSeries(json);
  }

  /// Deletes a declared series; a detected one comes back `dismissed` instead —
  /// the server decides which, since only it knows whether the ledger still
  /// supports the deduction.
  Future<void> delete(String seriesId) => _apiClient.delete('/recurring/$seriesId');

  Future<List<SeriesAccount>> listAccounts() async {
    final json = await _apiClient.get('/accounts') as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>())
        SeriesAccount(
          id: entry['id'] as String,
          name: entry['name'] as String,
          institution: entry['institution'] as String,
          currency: entry['currency'] as String,
        ),
    ];
  }

  Future<List<AppCategory>> listCategories() async {
    final json = await _apiClient.get('/categories') as List<dynamic>;
    return json
        .map((entry) => AppCategory.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  RecurringSeries _parseSeries(Map<String, dynamic> json) => RecurringSeries(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    label: json['label'] as String,
    categoryId: json['category_id'] as String?,
    cadence: Cadence.fromWire(json['cadence'] as String),
    medianIntervalDays: json['median_interval_days'] as int,
    expectedAmountMinor: json['expected_amount_minor'] as int,
    currency: json['currency'] as String,
    firstSeenDate: DateTime.parse(json['first_seen_date'] as String),
    lastSeenDate: DateTime.parse(json['last_seen_date'] as String),
    nextExpectedDate: DateTime.parse(json['next_expected_date'] as String),
    occurrenceCount: json['occurrence_count'] as int,
    status: SeriesStatus.fromWire(json['status'] as String),
    isManual: json['is_manual'] as bool,
    priceChangeMinor: json['price_change_minor'] as int?,
    priceChangedAt: json['price_changed_at'] == null
        ? null
        : DateTime.parse(json['price_changed_at'] as String),
  );

  SeriesOccurrence _parseOccurrence(Map<String, dynamic> json) {
    final transaction = json['transaction'] as Map<String, dynamic>;
    return SeriesOccurrence(
      id: json['id'] as String,
      transactionId: transaction['id'] as String,
      bookedDate: DateTime.parse(transaction['booked_date'] as String),
      amountMinor: transaction['amount_minor'] as int,
      currency: transaction['currency'] as String,
    );
  }

  RecurringSummary _parseSummary(Map<String, dynamic> json) {
    final nextCharge = json['next_charge'] as Map<String, dynamic>?;
    final cadenceCounts = json['cadence_counts'] as Map<String, dynamic>;

    return RecurringSummary(
      monthlyTotalMinor: json['monthly_total_minor'] as int,
      activeCount: json['active_count'] as int,
      cancelledCount: json['cancelled_count'] as int,
      cadenceCounts: {
        for (final entry in cadenceCounts.entries)
          Cadence.fromWire(entry.key): entry.value as int,
      },
      nextCharge: nextCharge == null
          ? null
          : NextCharge(
              seriesId: nextCharge['series_id'] as String,
              label: nextCharge['label'] as String,
              amountMinor: nextCharge['amount_minor'] as int,
              dueOn: DateTime.parse(nextCharge['due_on'] as String),
            ),
      priceIncreases: [
        for (final entry
            in (json['price_increases'] as List<dynamic>).cast<Map<String, dynamic>>())
          PriceIncrease(
            seriesId: entry['series_id'] as String,
            deltaMinor: entry['delta_minor'] as int,
            changedAt: DateTime.parse(entry['changed_at'] as String),
          ),
      ],
      missed: [
        for (final entry in (json['missed'] as List<dynamic>).cast<Map<String, dynamic>>())
          MissedCharge(
            seriesId: entry['series_id'] as String,
            expectedOn: DateTime.parse(entry['expected_on'] as String),
            daysLate: entry['days_late'] as int,
          ),
      ],
      currency: json['currency'] as String,
    );
  }
}

/// What one detection pass did. Series it deliberately left alone — manual,
/// dismissed, cancelled — count in neither number.
@immutable
class DetectionResult {
  const DetectionResult({required this.createdCount, required this.updatedCount});

  final int createdCount;
  final int updatedCount;
}

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(apiClientProvider));
});
