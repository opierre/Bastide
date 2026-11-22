import 'dart:async';

import 'package:window_manager/window_manager.dart';

import 'window_chrome.dart';

/// The native window through `package:window_manager`.
///
/// [open] hides the OS title bar and shows the window. The runners create
/// the window hidden (Windows, Linux) or already without a title bar (macOS),
/// so the native one never flashes on screen first.
class WindowManagerChrome with WindowListener implements WindowChrome {
  WindowStatus _status = const WindowStatus();
  final _changes = StreamController<WindowStatus>.broadcast();

  @override
  WindowStatus get status => _status;

  @override
  Stream<WindowStatus> get changes => _changes.stream;

  /// Takes over the window: hides its title bar (the edges still resize it),
  /// shows it, and starts following its state.
  Future<void> open() async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        // macOS keeps its own three buttons (`00` §5).
        windowButtonVisibility: true,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
    _set(
      WindowStatus(
        maximized: await windowManager.isMaximized(),
        focused: await windowManager.isFocused(),
      ),
    );
  }

  void _set(WindowStatus status) {
    if (status == _status) return;
    _status = status;
    _changes.add(status);
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  /// Posts the OS's own close request (`SC_CLOSE` on Windows), the one the
  /// native button sent: the window closes, the process exits, and the
  /// backend goes with it (stdin closes; on Windows the job object of
  /// `core/backend/windows_job.dart` ends it too).
  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  void onWindowFocus() => _set(_status.copyWith(focused: true));

  @override
  void onWindowBlur() => _set(_status.copyWith(focused: false));

  @override
  void onWindowMaximize() => _set(_status.copyWith(maximized: true));

  @override
  void onWindowUnmaximize() => _set(_status.copyWith(maximized: false));

  /// Back from the taskbar or the dock: the window may come back maximized.
  @override
  void onWindowRestore() {
    unawaited(
      windowManager.isMaximized().then(
        (maximized) => _set(_status.copyWith(maximized: maximized)),
      ),
    );
  }
}
