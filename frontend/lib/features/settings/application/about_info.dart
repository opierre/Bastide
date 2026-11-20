import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/backend/backend_providers.dart';

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

/// The database file the backend keeps everything in, under its data folder
/// (`backend/app/core/config.py` owns the name). `null` when the environment
/// does not say where home is.
final databaseFileProvider = Provider<String?>((ref) {
  final dir = ref.watch(dataDirProvider);
  if (dir == null) return null;
  // Joined in the folder's own style, which is the OS's.
  final style = dir.contains(r'\') ? p.Style.windows : p.Style.posix;
  return p.Context(style: style).join(dir, 'bastide.db');
});

/// Opens the data folder in the OS file manager.
final openDataFolderProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final dir = ref.read(dataDirProvider);
    if (dir == null) return;
    await launchUrl(Uri.directory(dir));
  };
});

/// Opens [url] in the default browser.
final openExternalUrlProvider = Provider<Future<void> Function(Uri)>((ref) {
  return (url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  };
});
