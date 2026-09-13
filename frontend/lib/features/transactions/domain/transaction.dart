import 'package:flutter/foundation.dart';

/// Mirrors the backend's `categorization_source` literal (`schemas.py`).
enum CategorizationSource {
  rule,
  model,
  user,
  uncategorized;

  static CategorizationSource fromWire(String value) =>
      CategorizationSource.values.firstWhere(
        (source) => source.name == value,
        orElse: () => CategorizationSource.uncategorized,
      );

  String get wireValue => name;
}

/// The category summary embedded on a transaction. `name` is an i18n key for
/// system categories and free text for user categories — see the i18n-l10n
/// skill and `category_display.dart`, which resolves it.
@immutable
class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String kind;
  final String icon;
  final String color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionCategory &&
          other.id == id &&
          other.name == name &&
          other.kind == kind &&
          other.icon == icon &&
          other.color == color);

  @override
  int get hashCode => Object.hash(id, name, kind, icon, color);
}

/// A transaction as returned by the API. Amount is the canonical signed
/// integer minor units — see the flutter-frontend skill; it is formatted only
/// at the presentation edge.
@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.bookedDate,
    required this.valueDate,
    required this.amountMinor,
    required this.currency,
    required this.descriptionRaw,
    required this.descriptionClean,
    required this.memo,
    required this.merchant,
    required this.category,
    required this.categorizationSource,
    required this.categorizationConfidence,
    required this.needsReview,
    required this.fitid,
    required this.dedupHash,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final DateTime bookedDate;
  final DateTime? valueDate;
  final int amountMinor;
  final String currency;
  final String descriptionRaw;
  final String descriptionClean;

  /// The bank's free-text detail for the row (OFX `MEMO`), when it carried one.
  /// Display-only, shown under the label; `null` when the statement carries no memo.
  final String? memo;
  final String? merchant;
  final TransactionCategory? category;
  final CategorizationSource categorizationSource;
  final double? categorizationConfidence;
  final bool needsReview;
  final String? fitid;
  final String dedupHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True when this row carries a stage-2 proposal the user has yet to judge.
  ///
  /// All four conditions matter: a `rule` or `user` row is settled and must not
  /// grow AI chrome, a row the model *assigned* has already left the queue, and
  /// a proposal without a confidence has nothing to show in the gauge beside it
  /// — so it is rendered as no proposal rather than as a silent one.
  bool get hasModelProposal =>
      needsReview &&
      categorizationSource == CategorizationSource.model &&
      category != null &&
      categorizationConfidence != null;

  Transaction copyWith({
    TransactionCategory? category,
    bool clearCategory = false,
    CategorizationSource? categorizationSource,
    bool? needsReview,
  }) {
    return Transaction(
      id: id,
      accountId: accountId,
      bookedDate: bookedDate,
      valueDate: valueDate,
      amountMinor: amountMinor,
      currency: currency,
      descriptionRaw: descriptionRaw,
      descriptionClean: descriptionClean,
      memo: memo,
      merchant: merchant,
      category: clearCategory ? null : (category ?? this.category),
      categorizationSource: categorizationSource ?? this.categorizationSource,
      categorizationConfidence: categorizationConfidence,
      needsReview: needsReview ?? this.needsReview,
      fitid: fitid,
      dedupHash: dedupHash,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == id &&
          other.accountId == accountId &&
          other.bookedDate == bookedDate &&
          other.valueDate == valueDate &&
          other.amountMinor == amountMinor &&
          other.currency == currency &&
          other.descriptionRaw == descriptionRaw &&
          other.descriptionClean == descriptionClean &&
          other.memo == memo &&
          other.merchant == merchant &&
          other.category == category &&
          other.categorizationSource == categorizationSource &&
          other.categorizationConfidence == categorizationConfidence &&
          other.needsReview == needsReview &&
          other.fitid == fitid &&
          other.dedupHash == dedupHash &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    bookedDate,
    valueDate,
    amountMinor,
    currency,
    descriptionRaw,
    descriptionClean,
    memo,
    merchant,
    category,
    categorizationSource,
    categorizationConfidence,
    needsReview,
    Object.hash(fitid, dedupHash, createdAt, updatedAt),
  );
}

/// One page of a filtered, paginated transaction listing (`GET /transactions`).
@immutable
class TransactionsPage {
  const TransactionsPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<Transaction> items;
  final int page;
  final int pageSize;
  final int total;

  int get totalPages => total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
}
