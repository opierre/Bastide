import 'package:path/path.dart' as p;

/// The places a packaged build keeps the frozen backend, relative to the app's
/// own executable, most likely first.
///
/// - Windows and Linux: `backend/` next to the executable (the Flutter bundle
///   is a folder, and the backend folder is copied into it).
/// - macOS: `Contents/Resources/backend/`, the executable being in
///   `Contents/MacOS/`.
List<String> backendExecutableCandidates({
  required String appExecutable,
  required String operatingSystem,
}) {
  final path = operatingSystem == 'windows' ? p.windows : p.posix;
  final appDir = path.dirname(appExecutable);
  return switch (operatingSystem) {
    'windows' => [path.join(appDir, 'backend', 'bastide-backend.exe')],
    'macos' => [
      path.normalize(
        path.join(appDir, '..', 'Resources', 'backend', 'bastide-backend'),
      ),
    ],
    _ => [path.join(appDir, 'backend', 'bastide-backend')],
  };
}

/// The backend executable to start: [override] when given (a developer
/// pointing at their own build), otherwise the first packaged location that
/// exists. `null` when there is none.
String? locateBackendExecutable({
  required String appExecutable,
  required String operatingSystem,
  required bool Function(String path) exists,
  String? override,
}) {
  if (override != null && override.isNotEmpty) return override;
  for (final candidate in backendExecutableCandidates(
    appExecutable: appExecutable,
    operatingSystem: operatingSystem,
  )) {
    if (exists(candidate)) return candidate;
  }
  return null;
}
