import 'dart:async';

import 'package:flutter/foundation.dart';

/// What the window controls draw from: whether the window fills the screen
/// (Agrandir or Restaurer) and whether it has the focus (inactive dims the
/// title and the icons, `00` §5).
@immutable
class WindowStatus {
  const WindowStatus({this.maximized = false, this.focused = true});

  final bool maximized;
  final bool focused;

  WindowStatus copyWith({bool? maximized, bool? focused}) => WindowStatus(
    maximized: maximized ?? this.maximized,
    focused: focused ?? this.focused,
  );

  @override
  bool operator ==(Object other) =>
      other is WindowStatus &&
      other.maximized == maximized &&
      other.focused == focused;

  @override
  int get hashCode => Object.hash(maximized, focused);
}

/// The native window, as the app's own title bar drives it.
///
/// The app draws its title bar instead of the OS (`docs/design/00` §5), so
/// moving, maximizing, minimizing and closing go through here. The packaged
/// app uses `WindowManagerChrome`; tests and anything without a native window
/// use [HeadlessWindowChrome].
abstract interface class WindowChrome {
  /// The window's state now.
  WindowStatus get status;

  /// Every later change of [status].
  Stream<WindowStatus> get changes;

  Future<void> minimize();

  /// Maximizes the window, or restores it when it is maximized.
  Future<void> toggleMaximize();

  /// Asks the OS to close the window, exactly as its own close button did:
  /// the app then exits by its usual path, which stops the backend.
  Future<void> close();

  /// Hands the current pointer drag to the OS to move the window.
  Future<void> startDragging();
}

/// A window that does nothing: the default until `main` attaches the real one,
/// and the window of widget tests.
class HeadlessWindowChrome implements WindowChrome {
  const HeadlessWindowChrome();

  @override
  WindowStatus get status => const WindowStatus();

  @override
  Stream<WindowStatus> get changes => const Stream.empty();

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> startDragging() async {}
}
