import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/backup.dart';

/// Calls `/backup` (`PROJECT.md` §5b, §14). The only place that knows its wire
/// shapes — including that an export's summary rides in a response header.
class BackupRepository {
  BackupRepository(this._apiClient);

  final ApiClient _apiClient;

  static const _summaryHeader = 'x-backup-summary';

  Future<BackupExport> export() async {
    final response = await _apiClient.postForBytes('/backup/export');
    final header = response.headers[_summaryHeader];
    if (header == null) throw ApiFailure.unknown();
    return BackupExport(
      bytes: response.bytes,
      summary: BackupSummary.fromJson(jsonDecode(header) as Map<String, dynamic>),
    );
  }

  /// What an archive holds. Refuses one this build cannot restore without
  /// touching any data.
  Future<BackupSummary> inspect(String fileName, List<int> bytes) =>
      _upload('/backup/inspect', fileName, bytes);

  /// Replaces all of the user's data with the archive's.
  Future<BackupSummary> restore(String fileName, List<int> bytes) =>
      _upload('/backup/restore', fileName, bytes);

  Future<BackupSummary> _upload(String path, String fileName, List<int> bytes) async {
    final json = await _apiClient.postMultipart(
      path,
      fileField: 'file',
      fileName: fileName,
      fileBytes: bytes,
    );
    return BackupSummary.fromJson(json as Map<String, dynamic>);
  }
}

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(apiClientProvider));
});
