import 'package:flutter/foundation.dart';

/// What `GET /settings/data-location` reports: where the running backend
/// keeps its data, as it resolved it.
///
/// The backend is the only one that knows: `--data-dir` or `BASTIDE_DB_PATH`
/// can move the datastore away from the default folder the app would derive.
@immutable
class DataLocation {
  const DataLocation({required this.dbPath, required this.dataDir});

  factory DataLocation.fromJson(Map<String, dynamic> json) => DataLocation(
    dbPath: json['db_path'] as String,
    dataDir: json['data_dir'] as String,
  );

  /// The database file.
  final String dbPath;

  /// The folder holding the database, and beside it the backups and logs.
  final String dataDir;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataLocation &&
          other.dbPath == dbPath &&
          other.dataDir == dataDir);

  @override
  int get hashCode => Object.hash(dbPath, dataDir);
}
