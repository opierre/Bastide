import 'package:flutter/foundation.dart';

/// How a bank's CSV encodes the direction of a movement: one signed column, or
/// separate debit and credit columns. Mirrors `csv_templates.amount_strategy`.
enum AmountStrategy {
  signed,
  debitCredit;

  static AmountStrategy fromWire(String value) =>
      value == 'debit_credit' ? AmountStrategy.debitCredit : AmountStrategy.signed;

  String get wireValue => this == AmountStrategy.debitCredit ? 'debit_credit' : 'signed';
}

/// The canonical field names a `column_map` may key. The backend's CSV parser
/// looks these exact strings up, so they are pinned here rather than typed at
/// each call site.
abstract final class CsvField {
  static const bookedDate = 'booked_date';
  static const valueDate = 'value_date';
  static const description = 'description';
  static const amount = 'amount';
  static const debit = 'debit';
  static const credit = 'credit';

  /// The fields the backend requires for a given strategy — the frontend
  /// mirrors the check so an incomplete mapping is caught before the round
  /// trip. `value_date` stays optional under both.
  static List<String> requiredFor(AmountStrategy strategy) =>
      strategy == AmountStrategy.debitCredit
      ? const [bookedDate, description, debit, credit]
      : const [bookedDate, description, amount];
}

/// A CSV mapping the user is still editing — the payload for both the preview
/// and the save calls, neither of which needs an id.
///
/// Defaults mirror French bank exports (`;`, Latin-1, `dd/MM/yyyy`, decimal
/// comma) so the common case needs almost no editing — see the ofx-csv-import
/// skill and `docs/design/06-imports.md`.
@immutable
class CsvTemplateDraft {
  const CsvTemplateDraft({
    this.bankName = '',
    this.delimiter = ';',
    this.encoding = 'latin-1',
    this.dateFormat = '%d/%m/%Y',
    this.decimalSeparator = ',',
    this.amountStrategy = AmountStrategy.signed,
    this.columnMap = const {},
    this.headerOffset = 0,
  });

  final String bankName;
  final String delimiter;
  final String encoding;

  /// A Python `strptime` pattern — the backend parses dates with it directly.
  final String dateFormat;

  final String decimalSeparator;
  final AmountStrategy amountStrategy;

  /// Canonical field (see [CsvField]) → CSV column name, or a 0-based index.
  final Map<String, String> columnMap;

  /// Lines to drop before the header row, for banks that prepend a preamble.
  final int headerOffset;

  /// True once every field the chosen strategy requires has a column, so the
  /// UI can refuse to ask the backend for a preview it would only reject.
  bool get isMappingComplete => CsvField.requiredFor(
    amountStrategy,
  ).every((field) => (columnMap[field] ?? '').trim().isNotEmpty);

  CsvTemplateDraft copyWith({
    String? bankName,
    String? delimiter,
    String? encoding,
    String? dateFormat,
    String? decimalSeparator,
    AmountStrategy? amountStrategy,
    Map<String, String>? columnMap,
    int? headerOffset,
  }) => CsvTemplateDraft(
    bankName: bankName ?? this.bankName,
    delimiter: delimiter ?? this.delimiter,
    encoding: encoding ?? this.encoding,
    dateFormat: dateFormat ?? this.dateFormat,
    decimalSeparator: decimalSeparator ?? this.decimalSeparator,
    amountStrategy: amountStrategy ?? this.amountStrategy,
    columnMap: columnMap ?? this.columnMap,
    headerOffset: headerOffset ?? this.headerOffset,
  );

  /// Replaces one canonical field's column, dropping the entry when cleared so
  /// the map never carries an empty mapping the backend would reject.
  CsvTemplateDraft withColumn(String field, String column) {
    final updated = Map<String, String>.from(columnMap);
    if (column.trim().isEmpty) {
      updated.remove(field);
    } else {
      updated[field] = column.trim();
    }
    return copyWith(columnMap: updated);
  }
}

/// A saved per-bank template, reused on every subsequent import from that bank.
@immutable
class CsvTemplate {
  const CsvTemplate({required this.id, required this.draft, required this.createdAt});

  final String id;

  /// The mapping itself, in the same shape the wizard edits — so "reuse this
  /// template" and "edit a copy of it" are the same object.
  final CsvTemplateDraft draft;

  final DateTime createdAt;

  String get bankName => draft.bankName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CsvTemplate && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// One parsed sample row from the preview endpoint. Nothing is persisted — this
/// exists so the user sees how their mapping reads the file before committing.
@immutable
class CsvPreviewRow {
  const CsvPreviewRow({
    required this.bookedDate,
    required this.valueDate,
    required this.amountMinor,
    required this.descriptionRaw,
  });

  final DateTime bookedDate;
  final DateTime? valueDate;

  /// Signed integer minor units, exactly as the ledger would store it.
  final int amountMinor;

  final String descriptionRaw;
}
