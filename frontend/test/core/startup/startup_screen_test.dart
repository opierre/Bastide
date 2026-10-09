import 'package:bastide/app.dart';
import 'package:bastide/core/backend/backend_connection.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/core/l10n/locale_provider.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend.dart';

class _EnLocale extends LocaleController {
  @override
  Locale build() => const Locale('en');
}

void main() {
  late ScriptedBackendController backend;
  late int logsOpened;

  Future<void> pumpApp(
    WidgetTester tester, {
    BackendFailure? failure,
    bool english = false,
  }) async {
    backend = ScriptedBackendController(failure: failure);
    logsOpened = 0;
    await tester.pumpWidget(
      ProviderScope(
        // A fresh scope per pump: a test may pump fr, then en.
        key: UniqueKey(),
        overrides: [
          backendControllerProvider.overrideWith(() => backend),
          openLogsFolderProvider.overrideWithValue(() async => logsOpened++),
          authControllerProvider.overrideWith(FakeAuthController.new),
          if (english) localeProvider.overrideWith(_EnLocale.new),
        ],
        child: const BastideApp(),
      ),
    );
    // One frame for the failed future to settle, one to render it.
    await tester.pump();
    await tester.pump();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('shows a splash while the backend starts', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('startupLoading')), findsOneWidget);
    expect(find.text('Démarrage de Bastide…'), findsOneWidget);
    expect(find.byKey(const Key('startupRetry')), findsNothing);
  });

  testWidgets('the app proper appears once the backend is ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendControllerProvider.overrideWith(ReadyBackendController.new),
          authControllerProvider.overrideWith(FakeAuthController.new),
        ],
        child: const BastideApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startupLoading')), findsNothing);
    expect(find.byKey(const Key('authPrivacyLine')), findsOneWidget);
  });

  final cases = {
    BackendFailureKind.timeout: (
      "Bastide n'a pas pu démarrer",
      "Bastide couldn't start",
    ),
    BackendFailureKind.notFound: (
      "Bastide n'a pas pu démarrer",
      "Bastide couldn't start",
    ),
    BackendFailureKind.crashed: (
      "Bastide s'est arrêté de façon inattendue",
      'Bastide stopped unexpectedly',
    ),
    BackendFailureKind.schemaTooNew: (
      "Ces données viennent d'une version plus récente",
      'This data comes from a newer version',
    ),
  };

  for (final MapEntry(key: kind, value: (fr, en)) in cases.entries) {
    testWidgets('${kind.name}: localized title in fr and en', (tester) async {
      await pumpApp(tester, failure: BackendFailure(kind));
      expect(textOf(tester, 'startupFailureTitle'), fr);
      expect(find.text('Ouvrir le dossier des journaux'), findsOneWidget);

      await pumpApp(tester, failure: BackendFailure(kind), english: true);
      expect(textOf(tester, 'startupFailureTitle'), en);
      expect(find.text('Open logs folder'), findsOneWidget);
    });
  }

  testWidgets('the schema message reassures that nothing changed', (
    tester,
  ) async {
    await pumpApp(
      tester,
      failure: const BackendFailure(BackendFailureKind.schemaTooNew),
      english: true,
    );

    expect(
      textOf(tester, 'startupFailureMessage'),
      contains('nothing has been changed'),
    );
  });

  testWidgets('retry and open logs reach the controller', (tester) async {
    await pumpApp(
      tester,
      failure: const BackendFailure(BackendFailureKind.crashed),
    );

    await tester.tap(find.byKey(const Key('startupRetry')));
    await tester.tap(find.byKey(const Key('startupOpenLogs')));
    await tester.pump();

    expect(backend.retries, 1);
    expect(logsOpened, 1);
  });
}
