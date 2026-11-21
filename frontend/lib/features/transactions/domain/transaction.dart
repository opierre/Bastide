import 'package:flutter/foundation.dart';

import '../../../core/logos/logo_ref.dart';

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
    this.excludedFromTotals = false,
    required this.fitid,
    required this.dedupHash,
    this.recurringSeriesId,
    this.logo,
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

  /// Kept out of the totals by the user: still listed, dimmed, and left out of
  /// the list's net and the dashboard's figures.
  final bool excludedFromTotals;
  final String? fitid;
  final String dedupHash;

  /// The recurring series this transaction is an occurrence of, `null` when it
  /// belongs to none.
  final String? recurringSeriesId;

  /// The rule logo the chip shows instead of the monogram; `null` for none.
  final LogoRef? logo;
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
    bool? excludedFromTotals,
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
      excludedFromTotals: excludedFromTotals ?? this.excludedFromTotals,
      fitid: fitid,
      dedupHash: dedupHash,
      recurringSeriesId: recurringSeriesId,
      logo: logo,
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
          other.excludedFromTotals == excludedFromTotals &&
          other.fitid == fitid &&
          other.dedupHash == dedupHash &&
          other.recurringSeriesId == recurringSeriesId &&
          other.logo == logo &&
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
    Object.hash(
      excludedFromTotals,
      fitid,
      dedupHash,
      recurringSeriesId,
      logo,
      createdAt,
      updatedAt,
    ),
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
    this.netMinor,
  });

  final List<Transaction> items;
  final int page;
  final int pageSize;
  final int total;

  /// The signed sum of every row the filters match, across all pages, rows
  /// excluded from totals aside. `null` when the API did not report it.
  final int? netMinor;

  int get totalPages => total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;

  /// The 1-based positions of the first and last rows on this page.
  int get firstIndex => total == 0 ? 0 : ((page - 1) * pageSize) + 1;
  int get lastIndex => ((page - 1) * pageSize) + items.length;
}

/// The rule that files a transaction, as its inspector names it.
@immutable
class TransactionRuleRef {
  const TransactionRuleRef({required this.id, required this.pattern});

  final String id;
  final String pattern;
}

/// The recurring series a transaction belongs to, as its inspector shows it.
/// [cadence] is the wire value (`monthly`, `yearly`…), read by the recurring
/// feature's own labels.
@immutable
class TransactionSeriesRef {
  const TransactionSeriesRef({
    required this.id,
    required this.cadence,
    required this.nextExpectedDate,
  });

  final String id;
  final String cadence;
  final DateTime nextExpectedDate;
}

/// An earlier operation of the same merchant.
@immutable
class SameMerchantOperation {
  const SameMerchantOperation({
    required this.id,
    required this.bookedDate,
    required this.amountMinor,
    required this.currency,
  });

  final String id;
  final DateTime bookedDate;
  final int amountMinor;
  final String currency;
}

/// What the inspector shows around a transaction, beyond the row itself
/// (`GET /transactions/{id}/context`).
@immutable
class TransactionContext {
  const TransactionContext({
    required this.importBatchId,
    required this.importFileName,
    required this.rule,
    required this.series,
    required this.sameMerchant,
  });

  final String importBatchId;
  final String? importFileName;

  /// Set only when a rule filed the row.
  final TransactionRuleRef? rule;
  final TransactionSeriesRef? series;

  /// Up to five earlier operations, newest first.
  final List<SameMerchantOperation> sameMerchant;
}
