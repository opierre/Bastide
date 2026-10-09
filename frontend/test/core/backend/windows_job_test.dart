@TestOn('windows')
library;

import 'dart:io';

import 'package:bastide/core/backend/windows_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closing the job kills the processes in it', () async {
    // A child that would otherwise run for a minute.
    final child = await Process.start('ping', ['-n', '60', '127.0.0.1']);
    addTearDown(child.kill);
    child.stdout.drain<void>();
    child.stderr.drain<void>();

    final job = WindowsJob.create()!;
    expect(job.assign(child.pid), isTrue);

    // What the kernel does when the app process dies with the handle open.
    job.close();

    // Gone within seconds rather than the minute it would have run; the
    // kernel ends job members with exit code 0, so the timing is the proof.
    await expectLater(
      child.exitCode.timeout(const Duration(seconds: 5)),
      completes,
    );
  });

  test('a process that no longer exists cannot be assigned', () async {
    final child = await Process.start('cmd', ['/c', 'exit', '0']);
    await child.exitCode;

    final job = WindowsJob.create()!;
    addTearDown(job.close);
    expect(job.assign(child.pid), isFalse);
  });
}
