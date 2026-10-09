import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/backend/backend_providers.dart';
import 'core/backend/instance_lock.dart';

void main() {
  final container = ProviderContainer();

  // Only an app that starts its own backend owns the data folder; a dev
  // build on an external backend leaves that to whoever started it.
  final dataDir = container.read(dataDirProvider);
  if (container.read(externalBackendProvider) == null && dataDir != null) {
    if (InstanceLock.acquire(dataDir) == null) exit(0);
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const BastideApp()),
  );
}
