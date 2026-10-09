import 'dart:io';

/// An exclusive lock on `bastide.lock` in the data folder, held for the life
/// of the app.
///
/// Two copies of the app would start two backends on one SQLite file. The
/// native runners already turn a second launch into focusing the first
/// window (a named mutex on Windows, a unique GApplication on Linux, Launch
/// Services on macOS); this lock is the guarantee behind them, for the cases
/// they miss — `open -n` on macOS, two unpacked portable copies. The OS
/// releases it when the process ends, even on a crash.
class InstanceLock {
  InstanceLock._(this._file);

  static const fileName = 'bastide.lock';

  final RandomAccessFile _file;

  /// Takes the lock in [dataDir], creating the folder on a first launch.
  /// Returns `null` when another running instance holds it.
  static InstanceLock? acquire(String dataDir) {
    Directory(dataDir).createSync(recursive: true);
    final file = File(
      '$dataDir${Platform.pathSeparator}$fileName',
    ).openSync(mode: FileMode.append);
    try {
      file.lockSync(FileLock.exclusive);
    } on FileSystemException {
      file.closeSync();
      return null;
    }
    return InstanceLock._(file);
  }

  /// Gives the lock up; only tests need to, the app holds it until it exits.
  void release() {
    _file.unlockSync();
    _file.closeSync();
  }
}
