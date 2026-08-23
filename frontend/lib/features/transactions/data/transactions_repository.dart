import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../../categories/domain/category.dart';
import '../domain/transaction.dart';

final _isoDate = DateFormat('yyyy-MM-dd');

/// Calls the `/transactions`, `/categories` and `/rules` endpoints and maps
/// the wire JSON to domain models.
///
/// The two foreign calls serve affordances that belong to *this* panel — the
/// category picker, and "always categorize like this" — so they stay here
/// rather than reaching into the categories/rules controllers, which hold the
/// state of a panel this one never shows. Only the [AppCategory] shape is
/// shared, because a second shape for the same resource is the one thing worse
/// than a shared one.
class TransactionsRepository {
  TransactionsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<TransactionsPage> list({
    String? accountId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool? needsReview,
    String? q,
    int page = 1,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'account_id': ?accountId,
      if (dateFrom != null) 'from': _isoDate.format(dateFrom),
      if (dateTo != null) 'to': _isoDate.format(dateTo),
      'category_id': ?categoryId,
      if (needsReview != null) 'needs_review': '$needsReview',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final json =
        await _apiClient.get('/transactions', query: query) as Map<String, dynamic>;
    return TransactionsPage(
      items: (json['items'] as List<dynamic>)
          .map((entry) => _parse(entry as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      total: json['total'] as int,
    );
  }

  Future<Transaction> update(
    String id, {
    String? categoryId,
    String? descriptionClean,
    String? merchant,
  }) async {
    final json = await _apiClient.patch(
      '/transactions/$id',
      body: {
        'category_id': ?categoryId,
        'description_clean': ?descriptionClean,
        'merchant': ?merchant,
      },
    );
    return _parse(json as Map<String, dynamic>);
  }

  Future<List<AppCategory>> listCategories() async {
    final json = await _apiClient.get('/categories') as List<dynamic>;
    return json
        .map((entry) => AppCategory.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Creates a rule matching [pattern] on [matchField] to [categoryId], so the
  /// rule engine picks up transactions like this one automatically from now
  /// on (see the ai-categorization skill's learning-loop pattern).
  ///
  /// Priority is placed after every existing rule: this transaction already
  /// fell through every enabled rule to reach the review queue, so nothing
  /// currently matches it and ordering relative to the existing set can't
  /// change today's outcome — only future imports.
  Future<void> alwaysCategorizeAs({
    required String matchField,
    required String pattern,
    required String categoryId,
  }) async {
    final existing = await _apiClient.get('/rules') as List<dynamic>;
    await _apiClient.post(
      '/rules',
      body: {
        'priority': existing.length + 1,
        'match_field': matchField,
        'match_type': 'contains',
        'pattern': pattern,
        'category_id': categoryId,
        'enabled': true,
      },
    );
  }

  Transaction _parse(Map<String, dynamic> json) {
    final categoryJson = json['category'] as Map<String, dynamic>?;
    return Transaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      bookedDate: DateTime.parse(json['booked_date'] as String),
      valueDate: json['value_date'] == null
          ? null
          : DateTime.parse(json['value_date'] as String),
      amountMinor: json['amount_minor'] as int,
      currency: json['currency'] as String,
      descriptionRaw: json['description_raw'] as String,
      descriptionClean: json['description_clean'] as String,
      memo: json['memo'] as String?,
      merchant: json['merchant'] as String?,
      category: categoryJson == null
          ? null
          : TransactionCategory(
              id: categoryJson['id'] as String,
              name: categoryJson['name'] as String,
              kind: categoryJson['kind'] as String,
              icon: categoryJson['icon'] as String,
              color: categoryJson['color'] as String,
            ),
      categorizationSource: CategorizationSource.fromWire(
        json['categorization_source'] as String,
      ),
      categorizationConfidence: (json['categorization_confidence'] as num?)?.toDouble(),
      needsReview: json['needs_review'] as bool,
      fitid: json['fitid'] as String?,
      dedupHash: json['dedup_hash'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(apiClientProvider));
});
