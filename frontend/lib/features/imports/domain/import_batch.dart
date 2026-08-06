import 'package:flutter/foundation.dart';

/// The file format a batch was parsed from. Mirrors `import_batches.source_format`.
enum ImportFormat {
  ofx,
  qfx,
  csv;

  static ImportFormat fromWire(String value) => ImportFormat.values.firstWhere(
    (format) => format.name == value,
    orElse: () => ImportFormat.csv,
  );
}

/// Outcome of an import. `partial` means some rows landed and some didn't;
/// `failed` means the file couldn't be parsed at all and nothing was written.
enum ImportStatus {
  success,
  partial,
  failed;

  /// An unrecognized status is treated as [failed] rather than [success]: the
  /// safe reading of "we don't know what happened" is that it didn't work.
  static ImportStatus fromWire(String value) => ImportStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => ImportStatus.failed,
  );
}

/// One import run: which file went into which account, what it covered, how
/// many rows were new versus duplicates, and how it ended.
///
/// `periodStart`/`periodEnd` are dates without a time component; they are the
/// coverage window derived from the file's contents by the backend.
@immutable
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.accountId,
    required this.sourceFormat,
    required this.fileName,
    required this.fileHash,
    required this.periodStart,
    required this.periodEnd,
    required this.transactionCount,
    required this.newCount,
    required this.duplicateCount,
    required this.status,
    required this.errorMessage,
    required this.balanceMismatchMinor,
    required this.balanceMismatchAsOf,
    required this.importedAt,
  });

  final String id;
  final String accountId;
  final ImportFormat sourceFormat;
  final String fileName;
  final String fileHash;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int transactionCount;
  final int newCount;
  final int duplicateCount;
  final ImportStatus status;

  /// The parser's own message, shown verbatim on a failed batch — it is the
  /// only thing that says *why* the file was rejected.
  final String? errorMessage;

  /// Set only from this account's second statement import onward, and only
  /// when the statement's declared balance disagrees with what the ledger
  /// implies at [balanceMismatchAsOf] — see the backend's
  /// `ImportService._detect_balance_mismatch`. `null` means either nothing was
  /// declared to compare (CSV, or an OFX file without `LEDGERBAL`) or the two
  /// agreed.
  final int? balanceMismatchMinor;
  final DateTime? balanceMismatchAsOf;

  final DateTime importedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportBatch &&
          other.id == id &&
          other.accountId == accountId &&
          other.sourceFormat == sourceFormat &&
          other.fileName == fileName &&
          other.fileHash == fileHash &&
          other.periodStart == periodStart &&
          other.periodEnd == periodEnd &&
          other.transactionCount == transactionCount &&
          other.newCount == newCount &&
          other.duplicateCount == duplicateCount &&
          other.status == status &&
          other.errorMessage == errorMessage &&
          other.balanceMismatchMinor == balanceMismatchMinor &&
          other.balanceMismatchAsOf == balanceMismatchAsOf &&
          other.importedAt == importedAt);

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    sourceFormat,
    fileName,
    fileHash,
    periodStart,
    periodEnd,
    transactionCount,
    newCount,
    duplicateCount,
    status,
    errorMessage,
    balanceMismatchMinor,
    balanceMismatchAsOf,
    importedAt,
  );
}
