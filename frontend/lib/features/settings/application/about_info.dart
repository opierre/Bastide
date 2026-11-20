import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/settings_repository.dart';
import '../domain/data_location.dart';

/// The public repository, opened by « Code source ».
final sourceCodeUrl = Uri.parse('https://github.com/opierre/Bastide');

/// The installation guide in the user's language: French first, English for
/// every other locale.
Uri installGuideUrl(String languageCode) => Uri.parse(
  languageCode == 'fr'
      ? 'https://github.com/opierre/Bastide/blob/main/docs/install.fr.md'
      : 'https://github.com/opierre/Bastide/blob/main/docs/install.md',
);

/// The operating system the app runs on, as `Platform.operatingSystem` names
/// it. A provider so the About header can be tested on any host.
final operatingSystemProvider = Provider<String>(
  (ref) => Platform.operatingSystem,
);

/// Where the running backend keeps its data, as the backend resolved it.
///
/// Asked rather than derived from the default folder: a backend started with
/// `--data-dir` or `BASTIDE_DB_PATH` keeps it elsewhere. Auto-disposed so
/// reopening À propos asks again after a failure.
final dataLocationProvider = FutureProvider.autoDispose<DataLocation>(
  (ref) => ref.watch(settingsRepositoryProvider).dataLocation(),
);

/// Opens a folder in the OS file manager.
final openFolderProvider = Provider<Future<void> Function(String)>((ref) {
  return (dir) async {
    await launchUrl(Uri.directory(dir));
  };
});

/// Opens [url] in the default browser.
final openExternalUrlProvider = Provider<Future<void> Function(Uri)>((ref) {
  return (url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  };
});
