import 'package:flutter/foundation.dart';

/// What a `.bastide` archive holds, in the terms the restore modal lists.
@immutable
class BackupCounts {
  const BackupCounts({
    required this.accounts,
    required this.transactions,
    required this.categories,
    required this.rules,
    required this.recurring,
    required this.goals,
    required this.mortgages,
    required this.properties,
    required this.simulations,
  });

  factory BackupCounts.fromJson(Map<String, dynamic> json) => BackupCounts(
    accounts: json['accounts'] as int,
    transactions: json['transactions'] as int,
    categories: json['categories'] as int,
    rules: json['rules'] as int,
    recurring: json['recurring'] as int,
    goals: json['goals'] as int,
    mortgages: json['mortgages'] as int,
    properties: json['properties'] as int,
    simulations: json['simulations'] as int,
  );

  final int accounts;
  final int transactions;
  final int categories;
  final int rules;
  final int recurring;
  final int goals;
  final int mortgages;
  final int properties;
  final int simulations;
}

/// An archive's manifest, as inspect and restore return it
/// and as an export reports it.
@immutable
class BackupSummary {
  const BackupSummary({
    required this.formatVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.currency,
    required this.counts,
    this.lastImportAt,
  });

  factory BackupSummary.fromJson(Map<String, dynamic> json) => BackupSummary(
    formatVersion: json['format_version'] as int,
    appVersion: json['app_version'] as String,
    exportedAt: DateTime.parse(json['exported_at'] as String),
    currency: json['currency'] as String,
    lastImportAt: _parseInstant(json['last_import_at']),
    counts: BackupCounts.fromJson(json['counts'] as Map<String, dynamic>),
  );

  final int formatVersion;

  /// The backend version that wrote the file — shown, never compared.
  final String appVersion;
  final DateTime exportedAt;
  final String currency;

  /// When the newest import in the file ran: `null` for a profile that never
  /// imported, and for a file written before archives carried it.
  final DateTime? lastImportAt;
  final BackupCounts counts;

  /// Whether this backup was exported before [latestImport], the latest
  /// import of the data it would replace: restoring it would lose that import.
  bool predates(DateTime? latestImport) =>
      latestImport != null && exportedAt.isBefore(latestImport);
}

/// The data as it stands, in the terms of [BackupSummary]: the « Actuel »
/// column the restore confirmation sets beside the file's.
@immutable
class CurrentData {
  const CurrentData({
    required this.appVersion,
    required this.counts,
    this.lastImportAt,
  });

  factory CurrentData.fromJson(Map<String, dynamic> json) => CurrentData(
    appVersion: json['app_version'] as String,
    lastImportAt: _parseInstant(json['last_import_at']),
    counts: BackupCounts.fromJson(json['counts'] as Map<String, dynamic>),
  );

  /// The running backend's version, spelled as an archive records it.
  final String appVersion;
  final DateTime? lastImportAt;
  final BackupCounts counts;
}

DateTime? _parseInstant(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// A built archive, ready to be written where the user chose.
@immutable
class BackupExport {
  const BackupExport({required this.bytes, required this.summary});

  final Uint8List bytes;
  final BackupSummary summary;
}

/// A file the user picked and the server has inspected but nothing has
/// replaced yet. The modal confirms *this* — the same bytes are restored.
@immutable
class PendingRestore {
  const PendingRestore({
    required this.fileName,
    required this.bytes,
    required this.summary,
  });

  final String fileName;
  final Uint8List bytes;
  final BackupSummary summary;
}

/// Why a backup could not be restored — one per backend error code.
enum BackupFailure {
  tooNew,
  invalid,
  currencyMismatch,
  runActive,
  conflict,
  unknown;

  static BackupFailure fromCode(String? code) => switch (code) {
    'BACKUP_TOO_NEW' => tooNew,
    'BACKUP_INVALID' => invalid,
    'BACKUP_CURRENCY_MISMATCH' => currencyMismatch,
    'BACKUP_RUN_ACTIVE' => runActive,
    'BACKUP_CONFLICT' => conflict,
    _ => unknown,
  };
}

class BackupException implements Exception {
  const BackupException(this.failure);

  final BackupFailure failure;

  @override
  String toString() => 'BackupException($failure)';
}
