import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/runs/run_event.dart';
import 'package:bastide/core/runs/run_progress_client.dart';
import 'package:mocktail/mocktail.dart';

class MockRunProgressClient extends Mock implements RunProgressClient {}

const packImportRunId = 'pack-run-1';

/// A `RulePackImportRunRead` on the wire, with invented values.
Map<String, dynamic> packImportRunJson({
  String id = packImportRunId,
  String status = 'running',
  int logoDone = 0,
  int logoTotal = 0,
  Map<String, dynamic>? result,
  String? errorMessage,
}) => {
  'id': id,
  'status': status,
  'logo_done': logoDone,
  'logo_total': logoTotal,
  'result': result,
  'error_message': errorMessage,
  'created_at': '2026-05-14T10:00:00Z',
  'finished_at': status == 'running' ? null : '2026-05-14T10:00:05Z',
};

/// A `rule_pack_import` run event: [done] logos settled out of [total].
RunEvent packImportEvent(
  RunEventType type, {
  String runId = packImportRunId,
  int done = 0,
  int total = 0,
}) => RunEvent(
  runId: runId,
  kind: 'rule_pack_import',
  type: type,
  done: done,
  total: total,
  occurredAt: DateTime.utc(2026, 5, 14, 10),
);

/// The backend side of an import with no logo to download: the run starts,
/// the socket's first snapshot does not know it (it ended already), and the
/// REST snapshot carries [result].
///
/// Returns the progress client to override `runProgressClientProvider` with.
MockRunProgressClient stubQuickPackImport(
  ApiClient apiClient, {
  required Map<String, dynamic> result,
}) {
  when(
    () => apiClient.post('/rules/packs/import-runs', body: any(named: 'body')),
  ).thenAnswer((_) async => packImportRunJson());
  when(
    () => apiClient.get('/rules/packs/import-runs/$packImportRunId'),
  ).thenAnswer(
    (_) async => packImportRunJson(status: 'finished', result: result),
  );
  final progress = MockRunProgressClient();
  when(
    () => progress.watch(any()),
  ).thenAnswer((_) => Stream<RunUpdate>.value(const RunResync(null)));
  return progress;
}
