/// Whether the app and the backend were built as the same product version.
///
/// Both come from one git tag, but each toolchain spells it its own way: the
/// app reports the SemVer form (`0.2.0-rc.1`), the backend's Python package
/// metadata the PEP 440 form (`0.2.0rc1`). Build metadata (`+42`) is not part
/// of the version.
bool sameProductVersion(String app, String backend) =>
    _normalize(app) == _normalize(backend);

final _preRelease = RegExp(r'^(\d+\.\d+\.\d+)[-._]?([a-z]+)?[-._]?(\d+)?$');

String _normalize(String version) {
  final core = version.trim().toLowerCase().split('+').first;
  final match = _preRelease.firstMatch(core);
  if (match == null) return core;
  return [match.group(1), match.group(2) ?? '', match.group(3) ?? ''].join();
}
