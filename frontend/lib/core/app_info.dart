import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The application version, shown in Settings › À propos.
///
/// Read from the built app rather than kept as a constant: release builds set
/// it from the git tag (`--build-name`), and the backend reports the same
/// product version on `/health`.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);
