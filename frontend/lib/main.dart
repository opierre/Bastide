import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/backend/backend_providers.dart';
import 'core/backend/instance_lock.dart';
import 'core/navigation/sidebar_controller.dart';
import 'core/third_party_licenses.dart';
import 'core/window/window_manager_chrome.dart';
import 'core/window/window_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyLicenses();
  final window = WindowManagerChrome();
  final container = ProviderContainer(
    overrides: [windowChromeProvider.overrideWithValue(window)],
  );

  // Only an app that starts its own backend owns the data folder; a dev
  // build on an external backend leaves that to whoever started it.
  final dataDir = container.read(dataDirProvider);
  if (container.read(externalBackendProvider) == null && dataDir != null) {
    if (InstanceLock.acquire(dataDir) == null) exit(0);
  }

  // The runners create the window hidden; this hides the native title bar,
  // then shows the window (see WindowManagerChrome.open).
  unawaited(window.open());

  // Starts reading the saved sidebar state while the startup and login
  // screens show, so the shell opens at its saved width instead of flashing
  // the default first.
  container.read(sidebarCollapsedProvider);

  runApp(
    UncontrolledProviderScope(container: container, child: const BastideApp()),
  );
}
