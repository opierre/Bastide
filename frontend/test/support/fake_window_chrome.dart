import 'dart:async';

import 'package:bastide/core/window/window_chrome.dart';

/// A [WindowChrome] that records what the title bar asked of the window and
/// lets a test change the window's state.
class FakeWindowChrome implements WindowChrome {
  FakeWindowChrome([this._status = const WindowStatus()]);

  WindowStatus _status;
  final _changes = StreamController<WindowStatus>.broadcast();

  /// Every call, in order: `minimize`, `toggleMaximize`, `close`, `drag`.
  final calls = <String>[];

  /// What the OS would report next, e.g. after a maximize or a blur.
  void emit(WindowStatus status) {
    _status = status;
    _changes.add(status);
  }

  @override
  WindowStatus get status => _status;

  @override
  Stream<WindowStatus> get changes => _changes.stream;

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async => calls.add('toggleMaximize');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('drag');
}
