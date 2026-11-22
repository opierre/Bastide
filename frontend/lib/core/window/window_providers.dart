import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'window_chrome.dart';

/// The native window. `main` overrides it with the real one; everything else
/// (widget tests, previews) gets a window that does nothing.
final windowChromeProvider = Provider<WindowChrome>(
  (ref) => const HeadlessWindowChrome(),
);

/// Whether the OS draws the window buttons itself: macOS keeps its three
/// buttons at the top left, Windows and Linux get the app's own at the top
/// right (`docs/design/00-design-system.md` §5).
final systemWindowButtonsProvider = Provider<bool>(
  (ref) => defaultTargetPlatform == TargetPlatform.macOS,
);

/// The window's state, kept current as the OS changes it.
class WindowStatusController extends Notifier<WindowStatus> {
  @override
  WindowStatus build() {
    final chrome = ref.watch(windowChromeProvider);
    final subscription = chrome.changes.listen((status) => state = status);
    ref.onDispose(subscription.cancel);
    return chrome.status;
  }
}

final windowStatusProvider =
    NotifierProvider<WindowStatusController, WindowStatus>(
      WindowStatusController.new,
    );
