import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// Ends the backend with the app on Windows, however the app ends.
///
/// Closing stdin already stops the backend when the app exits or crashes, but
/// only if the backend is still reading it. A job object with
/// `KILL_ON_JOB_CLOSE` is enforced by the kernel instead: the job's only
/// handle is held by this process and never closed, so when the process
/// dies — even killed from Task Manager — the handle goes, and Windows kills
/// every process in the job.
///
/// Only the backend joins the job, not the app itself: anything the app
/// opens (the browser for a link, the file manager) must outlive it.
class WindowsJob {
  WindowsJob._(this._handle);

  final Pointer<Void> _handle;

  static WindowsJob? _app;

  /// Puts the process [pid] in the app's job, created on first use. Returns
  /// `false` (and the backend runs on, covered by stdin alone) if Windows
  /// refuses, e.g. when an outer job forbids nesting.
  static bool killWithApp(int pid) {
    final job = _app ??= create();
    return job?.assign(pid) ?? false;
  }

  /// A new job that kills its processes when its last handle closes.
  @visibleForTesting
  static WindowsJob? create() {
    final handle = _createJobObject(nullptr, nullptr);
    if (handle == nullptr) return null;

    final info = calloc<_ExtendedLimitInformation>();
    try {
      info.ref.basicLimitInformation.limitFlags = _jobObjectLimitKillOnJobClose;
      final ok = _setInformationJobObject(
        handle,
        _jobObjectExtendedLimitInformation,
        info.cast(),
        sizeOf<_ExtendedLimitInformation>(),
      );
      if (ok == 0) {
        _closeHandle(handle);
        return null;
      }
    } finally {
      calloc.free(info);
    }
    return WindowsJob._(handle);
  }

  /// Adds the process [pid] to this job.
  @visibleForTesting
  bool assign(int pid) {
    final process = _openProcess(_processSetQuota | _processTerminate, 0, pid);
    if (process == nullptr) return false;
    try {
      return _assignProcessToJobObject(_handle, process) != 0;
    } finally {
      _closeHandle(process);
    }
  }

  /// Closes the job, killing its processes. The app never does: its job
  /// closes when the process ends.
  @visibleForTesting
  void close() => _closeHandle(_handle);
}

const _jobObjectExtendedLimitInformation = 9;
const _jobObjectLimitKillOnJobClose = 0x2000;
const _processTerminate = 0x0001;
const _processSetQuota = 0x0100;

final class _BasicLimitInformation extends Struct {
  @Int64()
  external int perProcessUserTimeLimit;
  @Int64()
  external int perJobUserTimeLimit;
  @Uint32()
  external int limitFlags;
  @IntPtr()
  external int minimumWorkingSetSize;
  @IntPtr()
  external int maximumWorkingSetSize;
  @Uint32()
  external int activeProcessLimit;
  @IntPtr()
  external int affinity;
  @Uint32()
  external int priorityClass;
  @Uint32()
  external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64()
  external int readOperationCount;
  @Uint64()
  external int writeOperationCount;
  @Uint64()
  external int otherOperationCount;
  @Uint64()
  external int readTransferCount;
  @Uint64()
  external int writeTransferCount;
  @Uint64()
  external int otherTransferCount;
}

/// `JOBOBJECT_EXTENDED_LIMIT_INFORMATION`, which `package:win32` doesn't bind.
final class _ExtendedLimitInformation extends Struct {
  external _BasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;
  @IntPtr()
  external int processMemoryLimit;
  @IntPtr()
  external int jobMemoryLimit;
  @IntPtr()
  external int peakProcessMemoryUsed;
  @IntPtr()
  external int peakJobMemoryUsed;
}

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _createJobObject = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>),
      Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>)
    >('CreateJobObjectW');

final _setInformationJobObject = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int, Pointer<Void>, int)
    >('SetInformationJobObject');

final _openProcess = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Uint32, Int32, Uint32),
      Pointer<Void> Function(int, int, int)
    >('OpenProcess');

final _assignProcessToJobObject = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>),
      int Function(Pointer<Void>, Pointer<Void>)
    >('AssignProcessToJobObject');

final _closeHandle = _kernel32
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'CloseHandle',
    );
