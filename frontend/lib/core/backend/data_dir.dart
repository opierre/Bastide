import 'package:path/path.dart' as p;

/// The folder the backend keeps its database, backups and logs in.
///
/// Mirrors `platformdirs.user_data_dir("Bastide", appauthor=False,
/// roaming=False)` in `backend/app/core/config.py`, which owns the location:
/// the app only needs it to open the logs folder and to hold its lock file.
/// `null` when the environment doesn't say where home is.
String? bastideDataDir({
  required String operatingSystem,
  required Map<String, String> environment,
}) {
  String? nonEmpty(String key) {
    final value = environment[key];
    return value == null || value.isEmpty ? null : value;
  }

  switch (operatingSystem) {
    case 'windows':
      final local = nonEmpty('LOCALAPPDATA');
      return local == null ? null : p.windows.join(local, 'Bastide');
    case 'macos':
      final home = nonEmpty('HOME');
      return home == null
          ? null
          : p.posix.join(home, 'Library', 'Application Support', 'Bastide');
    default:
      final xdg = nonEmpty('XDG_DATA_HOME');
      if (xdg != null) return p.posix.join(xdg, 'Bastide');
      final home = nonEmpty('HOME');
      return home == null
          ? null
          : p.posix.join(home, '.local', 'share', 'Bastide');
  }
}
