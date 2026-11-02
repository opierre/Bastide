import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Declares a test whose timers run on a fake clock.
///
/// The body gets the [FakeAsync] and moves time with `time.elapse(...)`, so a
/// debounce is crossed instantly instead of waited for on the wall clock.
/// Mocked futures still resolve: they only need microtasks, which are flushed
/// after every step.
void fakeTimeTest(
  String description,
  Future<void> Function(FakeAsync time) body,
) {
  test(description, () {
    fakeAsync((time) {
      Object? error;
      StackTrace? stack;
      var done = false;
      body(time).then(
        (_) => done = true,
        onError: (Object e, StackTrace s) {
          error = e;
          stack = s;
          done = true;
        },
      );
      time.flushMicrotasks();
      if (error != null) Error.throwWithStackTrace(error!, stack!);
      if (!done) {
        fail('The test awaited something that never completes in fake time.');
      }
    });
  });
}
