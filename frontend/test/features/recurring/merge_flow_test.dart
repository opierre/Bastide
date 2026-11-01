import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/data/recurring_repository.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/presentation/subscriptions_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/recurring_fixtures.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

/// « Fusionner » end to end through the real controller, with only the
/// repository mocked: the click, the write, the reload and the feedback the
/// user sees for each outcome (issue #74).
void main() {
  late MockRecurringRepository repository;

  final pair = MergeSuggestion(
    target: testSeries(id: 's2', label: 'STREAMCO - STREAMCO TV'),
    source: testSeries(label: 'STREAMCO'),
  );

  setUp(() {
    repository = MockRecurringRepository();
    when(() => repository.summary()).thenAnswer((_) async => testSummary());
  });

  void stubPanel({
    required List<RecurringSeries> series,
    required List<MergeSuggestion> suggestions,
  }) {
    when(
      () => repository.list(status: any(named: 'status')),
    ).thenAnswer((_) async => series);
    when(
      () => repository.list(archived: true),
    ).thenAnswer((_) async => const <RecurringSeries>[]);
    when(
      () => repository.mergeSuggestions(),
    ).thenAnswer((_) async => suggestions);
  }

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringRepositoryProvider.overrideWithValue(repository),
          subscriptionCategoriesProvider.overrideWith(
            (ref) => const <AppCategory>[],
          ),
          subscriptionAccountsProvider.overrideWith(
            (ref) => const <SeriesAccount>[],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          theme: appDarkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SubscriptionsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a merge folds the pair into one row and says so', (
    tester,
  ) async {
    stubPanel(series: [pair.source, pair.target], suggestions: [pair]);
    when(
      () => repository.merge('s2', 's1'),
    ).thenAnswer((_) async => pair.target);
    await pumpPanel(tester);
    expect(find.text('STREAMCO'), findsWidgets);

    stubPanel(series: [pair.target], suggestions: const []);
    await tester.tap(find.byKey(const Key('subscriptionsMergeAction')));
    await tester.pumpAndSettle();

    verify(() => repository.merge('s2', 's1')).called(1);
    expect(find.byKey(const Key('subscriptionsMergeBanner')), findsNothing);
    expect(find.byKey(const Key('seriesAmount-s1')), findsNothing);
    expect(find.byKey(const Key('seriesAmount-s2')), findsOneWidget);
    expect(find.text('Abonnements fusionnés'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('a merge that cannot reach the server is reported, not frozen', (
    tester,
  ) async {
    stubPanel(series: [pair.source, pair.target], suggestions: [pair]);
    when(
      () => repository.merge(any(), any()),
    ).thenThrow(Exception('connection refused'));
    await pumpPanel(tester);

    await tester.tap(find.byKey(const Key('subscriptionsMergeAction')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscriptionsActionError')), findsOneWidget);
    expect(find.byKey(const Key('subscriptionsMergeBanner')), findsOneWidget);
    expect(find.text('Abonnements fusionnés'), findsNothing);
    // The button is released, so the user can try again.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
