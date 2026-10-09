import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A [Process] whose pipes and exit the test drives.
class FakeProcess implements Process {
  FakeProcess({this.exitOnStdinClose = true});

  /// Mirrors `--exit-on-stdin-close`: closing stdin makes it exit with 0.
  final bool exitOnStdinClose;

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;
  bool stdinClosed = false;

  late final IOSink _stdin = IOSink(_StdinConsumer(onClose: _onStdinClosed));

  void printOut(String line) => _stdout.add(utf8.encode('$line\n'));

  void printErr(String line) => _stderr.add(utf8.encode('$line\n'));

  void exit(int code) {
    if (_exit.isCompleted) return;
    _stdout.close();
    _stderr.close();
    _exit.complete(code);
  }

  void _onStdinClosed() {
    stdinClosed = true;
    if (exitOnStdinClose) exit(0);
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => 4242;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    exit(-1);
    return true;
  }
}

class _StdinConsumer implements StreamConsumer<List<int>> {
  _StdinConsumer({required this.onClose});

  final void Function() onClose;

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<void> close() async => onClose();
}
