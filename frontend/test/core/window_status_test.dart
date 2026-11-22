import 'package:bastide/core/window/window_chrome.dart';
import 'package:bastide/core/window/window_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_window_chrome.dart';

void main() {
  test('starts from the window state and follows its changes', () async {
    final chrome = FakeWindowChrome(const WindowStatus(maximized: true));
    final container = ProviderContainer(
      overrides: [windowChromeProvider.overrideWithValue(chrome)],
    );
    addTearDown(container.dispose);
    final seen = <WindowStatus>[];
    container.listen(
      windowStatusProvider,
      (_, next) => seen.add(next),
      fireImmediately: true,
    );

    chrome.emit(const WindowStatus(maximized: true, focused: false));
    await Future<void>.delayed(Duration.zero);
    chrome.emit(const WindowStatus());
    await Future<void>.delayed(Duration.zero);

    expect(seen, const [
      WindowStatus(maximized: true),
      WindowStatus(maximized: true, focused: false),
      WindowStatus(),
    ]);
  });

  test('without a native window, an active, restored window that does '
      'nothing', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(windowStatusProvider), const WindowStatus());
    await container.read(windowChromeProvider).close();
  });
}
