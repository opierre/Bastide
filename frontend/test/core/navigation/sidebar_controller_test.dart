import 'dart:async';

import 'package:bastide/core/navigation/sidebar_controller.dart';
import 'package:bastide/core/storage/ui_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_ui_preferences.dart';

ProviderContainer _container(UiPreferencesStore store) {
  final container = ProviderContainer(
    overrides: [uiPreferencesStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the controller's fire-and-forget read and write settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts expanded when nothing was saved', () async {
    final container = _container(FakeUiPreferencesStore());

    expect(container.read(sidebarCollapsedProvider), isFalse);
    await _settle();
    expect(container.read(sidebarCollapsedProvider), isFalse);
  });

  test('restores a collapsed sidebar saved on this device', () async {
    final container = _container(
      FakeUiPreferencesStore(sidebarCollapsed: true),
    );

    container.read(sidebarCollapsedProvider);
    await _settle();

    expect(container.read(sidebarCollapsedProvider), isTrue);
  });

  test('toggle and set save the choice', () async {
    final store = FakeUiPreferencesStore();
    final container = _container(store);
    final controller = container.read(sidebarCollapsedProvider.notifier);
    await _settle();

    controller.toggle();
    expect(container.read(sidebarCollapsedProvider), isTrue);
    controller.set(false);
    expect(container.read(sidebarCollapsedProvider), isFalse);
    // Choosing the current value writes nothing.
    controller.set(false);
    await _settle();

    expect(store.writes, [true, false]);
  });

  test(
    'a choice made while the saved value loads is not undone by it',
    () async {
      final gate = Completer<void>();
      final container = _container(
        FakeUiPreferencesStore(sidebarCollapsed: true, readGate: gate),
      );

      container.read(sidebarCollapsedProvider.notifier).set(false);
      // Already false: nothing to change, but the choice still counts.
      gate.complete();
      await _settle();

      expect(container.read(sidebarCollapsedProvider), isFalse);
    },
  );

  test('a broken store leaves the sidebar usable', () async {
    final container = _container(FailingUiPreferencesStore());

    container.read(sidebarCollapsedProvider.notifier).toggle();
    await _settle();

    expect(container.read(sidebarCollapsedProvider), isTrue);
  });
}
