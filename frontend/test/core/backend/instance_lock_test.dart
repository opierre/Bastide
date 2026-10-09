import 'dart:io';

import 'package:bastide/core/backend/instance_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('bastide-lock-'));
  tearDown(() => root.deleteSync(recursive: true));

  test('a first launch creates the data folder and takes the lock', () {
    final dataDir = '${root.path}${Platform.pathSeparator}Bastide';

    final lock = InstanceLock.acquire(dataDir);

    expect(lock, isNotNull);
    expect(
      File('$dataDir${Platform.pathSeparator}bastide.lock').existsSync(),
      isTrue,
    );
    lock!.release();
  });

  test('the lock is free again once released', () {
    InstanceLock.acquire(root.path)!.release();

    final again = InstanceLock.acquire(root.path);
    expect(again, isNotNull);
    again!.release();
  });

  // POSIX record locks belong to the process, so a second lock from the same
  // process succeeds there; Windows locks per handle, which lets one process
  // stand in for two.
  test('a second instance is refused while the first runs', () {
    final first = InstanceLock.acquire(root.path)!;

    expect(InstanceLock.acquire(root.path), isNull);
    first.release();
  }, testOn: 'windows');
}
