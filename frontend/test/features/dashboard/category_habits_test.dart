import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/core/widgets/state_views.dart';
import 'package:bastide/core/widgets/status_text.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/application/dashboard_habits_provider.dart';
import 'package:bastide/features/dashboard/data/dashboard_repository.dart';
import 'package:bastide/features/dashboard/domain/dashboard_habits.dart';
import 'package:bastide/features/dashboard/presentation/category_habits.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/dashboard_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

CategoryHabit _habit({
  String id = 'c1',
  int amountMinor = 12000,
  int? averageMinor = 10000,
}) => CategoryHabit(
  categoryId: id,
  name: 'category.food',
  hue: 'cat2',
  amountMinor: amountMinor,
  averageMinor: averageMinor,
  gapMinor: averageMinor == null ? null : amountMinor - averageMinor,
);

DashboardHabits _habits(
  List<CategoryHabit> rows, {
  int? totalGapMinor,
  int monthsCounted = 12,
}) => DashboardHabits(
  month: DateTime(2026, 5),
  monthsCounted: monthsCounted,
  rows: rows,
  totalGapMinor: totalGapMinor,
  currency: 'EUR',
);

String _money(int minor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: minor, currency: 'EUR', locale: locale);

Finder _byKey(String key) => find.byKey(Key(key));

Iterable<String> _rowIds(WidgetTester tester) => tester
    .widgetList(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('dashboardHabitRow-'),
      ),
    )
    .map(
      (w) => (w.key! as ValueKey<String>).value.substring(
        'dashboardHabitRow-'.length,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  DashboardHabits habits, {
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  double height = 420,
  ValueChanged<String?>? onTap,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            // Half the content width of the 1440 px frame.
            width: 556,
            height: height,
            child: CategoryHabits(
              habits: habits,
              onCategoryTap: onTap ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CategoryHabit', () {
    test('the repère runs from 0 to twice the average', () {
      expect(_habit(amountMinor: 10000).meterFraction, 0.5);
      expect(_habit(amountMinor: 5000).meterFraction, 0.25);
      expect(_habit(amountMinor: 30000).meterFraction, 1.0);
      expect(CategoryHabit.averageMarkFraction, 0.5);
    });

    test('fills over from 120 % of the average, not before', () {
      expect(_habit(amountMinor: 12000).isOver, isTrue);
      expect(_habit(amountMinor: 11999).isOver, isFalse);
      expect(_habit(amountMinor: 12001).isOver, isTrue);
      // A fall never goes over.
      expect(_habit(amountMinor: 4000).isOver, isFalse);
    });

    test('without history: no repère, no trend', () {
      final row = _habit(averageMinor: null);
      expect(row.hasHistory, isFalse);
      expect(row.meterFraction, 0);
      expect(row.isOver, isFalse);
      expect(row.trend, HabitTrend.flat);
    });

    test('the trend follows the sign of the gap', () {
      expect(_habit(amountMinor: 10500).trend, HabitTrend.rise);
      expect(_habit(amountMinor: 9500).trend, HabitTrend.fall);
      expect(_habit(amountMinor: 10000).trend, HabitTrend.flat);
    });

    test('at most eight rows, the API order kept', () {
      final rows = [for (var i = 0; i < 10; i++) _habit(id: 'r$i')];
      final shown = _habits(rows).shownRows;
      expect(shown, hasLength(DashboardHabits.maxRows));
      expect(shown.map((r) => r.categoryId), [
        for (var i = 0; i < 8; i++) 'r$i',
      ]);
    });
  });

  group('CategoryHabits', () {
    testWidgets('heading total, header, and rows in the API order', (
      tester,
    ) async {
      await _pump(tester, specHabits());

      expect(find.text('Par rapport à vos habitudes'), findsOneWidget);
      expect(
        tester.widget<Text>(_byKey('dashboardHabitsTotal')).data,
        '${_money(10299)} de plus que votre moyenne',
      );
      expect(find.text('Catégorie'), findsOneWidget);
      expect(
        tester.widget<Text>(_byKey('dashboardHabitsAverageHeader')).data,
        'moyenne sur 12 mois',
      );
      expect(
        tester.widget<Text>(_byKey('dashboardHabitsMonthHeader')).data,
        'Mai',
      );
      expect(find.text('Écart'), findsOneWidget);
      expect(_rowIds(tester), ['c2', 'c5', 'c4', 'c7', 'c6', 'c3', 'gifts']);
      expect(
        tester.getSize(_byKey('dashboardHabitRow-c2')).height,
        AppSizes.tableRow,
      );
      // The month's amount is unsigned and neutral.
      final amount = tester.widget<AmountText>(
        _byKey('dashboardHabitAmount-c2'),
      );
      expect(amount.amountMinor, 48620);
      expect(amount.colorize, isFalse);
      expect(find.text(_money(48620)), findsOneWidget);
    });

    testWidgets('repère: mark at the average, over from +20 %', (tester) async {
      await _pump(tester, specHabits());

      RepereMeter meter(String id) =>
          tester.widget<RepereMeter>(_byKey('dashboardHabitMeter-$id'));
      // Alimentation spends 123 % of its average, Loisirs 157 %.
      expect(meter('c2').tone, RepereTone.over);
      expect(meter('c5').tone, RepereTone.over);
      // Abonnements spends 112 %: a rise, but under the threshold.
      expect(meter('c6').tone, RepereTone.normal);
      expect(meter('c4').tone, RepereTone.normal);
      expect(meter('c2').markFraction, 0.5);
      expect(meter('c2').markLabel, isNull);
      expect(meter('c2').fraction, closeTo(48620 / 78760, 1e-9));
      // The track is centred in its row, with no room kept for a label.
      final row = tester.getRect(_byKey('dashboardHabitRow-c2'));
      final track = tester.getRect(
        find.descendant(
          of: _byKey('dashboardHabitMeter-c2'),
          matching: find.byKey(const Key('repereTrack')),
        ),
      );
      expect(track.center.dy, closeTo(row.center.dy, 1));
    });

    for (final (name, theme, colors) in [
      ('dark', AppTheme.dark, AppColors.dark),
      ('light', AppTheme.light, AppColors.light),
    ]) {
      testWidgets('gap colours and icons ($name)', (tester) async {
        await _pump(
          tester,
          _habits([
            _habit(id: 'up', amountMinor: 15000),
            _habit(id: 'down', amountMinor: 7000),
            _habit(id: 'flat', amountMinor: 10000),
          ], totalGapMinor: 2000),
          theme: theme,
        );

        StatusText gap(String id) =>
            tester.widget<StatusText>(_byKey('dashboardHabitGap-$id'));
        expect(gap('up').tone, StatusTone.negative);
        expect(gap('up').icon, LucideIcons300.trendingUp);
        expect(gap('up').label, _money(5000));
        expect(gap('down').tone, StatusTone.positive);
        expect(gap('down').icon, LucideIcons300.trendingDown);
        expect(gap('down').label, _money(3000));
        expect(gap('flat').tone, StatusTone.neutral);
        expect(gap('flat').icon, LucideIcons300.minus);

        Color iconColor(String id) => tester
            .widget<Icon>(
              find.descendant(
                of: _byKey('dashboardHabitGap-$id'),
                matching: find.byType(Icon),
              ),
            )
            .color!;
        expect(iconColor('up'), colors.negative);
        expect(iconColor('down'), colors.positive);
        expect(iconColor('flat'), colors.textSecondary);

        final fill = RepereTone.over.fill(colors);
        expect(fill, colors.warning);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a category without history says so, after the gaps', (
      tester,
    ) async {
      await _pump(tester, specHabits());

      expect(_byKey('dashboardHabitMeter-gifts'), findsNothing);
      final note = tester.widget<Text>(_byKey('dashboardHabitNoHistory-gifts'));
      expect(note.data, 'Aucune dépense sur les mois précédents');
      expect(note.style?.color, AppColors.dark.textTertiary);
      expect(tester.widget<Text>(_byKey('dashboardHabitGap-gifts')).data, '—');
      expect(_rowIds(tester).last, 'gifts');
    });

    testWidgets('the heading reads a fall, a tie, or nothing', (tester) async {
      await _pump(tester, _habits([_habit()], totalGapMinor: -4720));
      expect(
        tester.widget<Text>(_byKey('dashboardHabitsTotal')).data,
        '${_money(4720)} de moins que votre moyenne',
      );

      await _pump(tester, _habits([_habit()], totalGapMinor: 0));
      expect(
        tester.widget<Text>(_byKey('dashboardHabitsTotal')).data,
        'Égal à votre moyenne',
      );

      // The first month of data: no row has an average, so no total.
      await _pump(
        tester,
        _habits([_habit(averageMinor: null)], monthsCounted: 0),
      );
      expect(_byKey('dashboardHabitsTotal'), findsNothing);
      expect(
        tester.widget<Text>(_byKey('dashboardHabitsAverageHeader')).data,
        isEmpty,
      );
    });

    testWidgets('fewer months counted name their number', (tester) async {
      await _pump(tester, specHabits(monthsCounted: 5));

      expect(
        tester.widget<Text>(_byKey('dashboardHabitsAverageHeader')).data,
        'moyenne sur 5 mois',
      );
    });

    testWidgets('the month in progress carries the Note', (tester) async {
      await _pump(tester, specHabits(daysElapsed: 14));

      expect(
        find.text(
          'Mai n’est pas terminé : ces montants comparent '
          '14 jours à un mois entier.',
        ),
        findsOneWidget,
      );

      await _pump(tester, specHabits(daysElapsed: 1));
      expect(find.textContaining('1 jour à un mois'), findsOneWidget);

      await _pump(tester, specHabits());
      expect(_byKey('dashboardHabitsInProgress'), findsNothing);
    });

    testWidgets('at most eight rows, and only as many as fit', (tester) async {
      final rows = [for (var i = 0; i < 10; i++) _habit(id: 'r$i')];
      await _pump(tester, _habits(rows, totalGapMinor: 20000), height: 600);
      expect(_rowIds(tester), hasLength(8));

      await _pump(tester, _habits(rows, totalGapMinor: 20000), height: 200);
      expect(_rowIds(tester).length, lessThan(8));
      expect(_rowIds(tester).first, 'r0');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a month without spending shows the note', (tester) async {
      await _pump(tester, _habits(const []));

      expect(find.text('Aucune dépense ce mois.'), findsOneWidget);
      expect(_byKey('dashboardHabitsAverageHeader'), findsNothing);
    });

    testWidgets('a tap names the row\'s category', (tester) async {
      final taps = <String?>[];
      await _pump(tester, specHabits(), onTap: taps.add);

      await tester.tap(_byKey('dashboardHabitRow-c5'));
      expect(taps, ['c5']);
    });

    testWidgets('renders in en', (tester) async {
      await _pump(
        tester,
        specHabits(daysElapsed: 14),
        locale: const Locale('en'),
      );

      expect(find.text('Compared with your habits'), findsOneWidget);
      expect(
        tester.widget<Text>(_byKey('dashboardHabitsTotal')).data,
        '${_money(10299, locale: 'en')} more than your average',
      );
      expect(_money(10299, locale: 'en'), '€102.99');
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('12-month average'), findsOneWidget);
      expect(find.text('May'), findsOneWidget);
      expect(find.text('Gap'), findsOneWidget);
      expect(find.text('No spending in the previous months'), findsOneWidget);
      expect(
        find.text(
          'May is not over: these amounts compare 14 days with a full month.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DashboardHabitsBlock', () {
    Future<void> pumpBlock(
      WidgetTester tester,
      Future<DashboardHabits> Function() load,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dashboardHabitsProvider.overrideWith((ref) => load())],
          child: MaterialApp(
            locale: const Locale('fr'),
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 556,
                height: 300,
                child: DashboardHabitsBlock(onCategoryTap: (_, _) {}),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('loading draws its silhouette', (tester) async {
      await pumpBlock(tester, () => Completer<DashboardHabits>().future);
      await tester.pump();

      expect(_byKey('dashboardHabitsLoading'), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failure stays in the block, with « Réessayer »', (
      tester,
    ) async {
      await pumpBlock(
        tester,
        () => Future<DashboardHabits>.error(
          const ApiFailure(code: 'INTERNAL', message: 'boom'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(_byKey('dashboardHabitsRetryButton'), findsOneWidget);
    });
  });

  group('data', () {
    late MockApiClient apiClient;

    setUpAll(() => registerFallbackValue(<String, String>{}));

    setUp(() => apiClient = MockApiClient());

    Map<String, dynamic> habitsJson(String month) => {
      'month': month,
      'months_counted': 12,
      'rows': [
        {
          'category_id': 'c2',
          'name': 'category.food',
          'hue': 'cat2',
          'amount_minor': 48620,
          'average_minor': 39380,
          'gap_minor': 9240,
        },
        {
          'category_id': null,
          'name': 'category.uncategorized',
          'hue': 'cat0',
          'amount_minor': 4990,
          'average_minor': null,
          'gap_minor': null,
        },
      ],
      'total_gap_minor': 9240,
      'currency': 'EUR',
    };

    test('the repository maps the wire shape', () async {
      when(
        () => apiClient.get('/dashboard/habits', query: any(named: 'query')),
      ).thenAnswer((_) async => habitsJson('2026-05'));

      final habits = await DashboardRepository(
        apiClient,
      ).habits(DateTime(2026, 5), today: DateTime(2026, 7, 3));

      verify(
        () => apiClient.get('/dashboard/habits', query: {'month': '2026-05'}),
      ).called(1);
      expect(habits.month, DateTime(2026, 5));
      expect(habits.monthsCounted, 12);
      expect(habits.totalGapMinor, 9240);
      expect(habits.daysElapsed, isNull);
      final [food, uncategorized] = habits.rows;
      expect(food.categoryId, 'c2');
      expect(food.amountMinor, 48620);
      expect(food.averageMinor, 39380);
      expect(food.gapMinor, 9240);
      expect(uncategorized.categoryId, isNull);
      expect(uncategorized.averageMinor, isNull);
      expect(uncategorized.hasHistory, isFalse);
    });

    test('the month in progress carries the days elapsed', () async {
      when(
        () => apiClient.get('/dashboard/habits', query: any(named: 'query')),
      ).thenAnswer((_) async => habitsJson('2026-05'));

      final habits = await DashboardRepository(
        apiClient,
      ).habits(DateTime(2026, 5), today: DateTime(2026, 5, 14, 18));

      expect(habits.daysElapsed, 14);
      expect(habits.isInProgress, isTrue);
    });

    test('the habits follow the month the dashboard shows', () async {
      when(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).thenAnswer(
        (_) async => {
          'items': const [],
          'page': 1,
          'page_size': 50,
          'total': 0,
        },
      );
      when(() => apiClient.get('/accounts')).thenAnswer((_) async => const []);
      when(
        () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
      ).thenAnswer(
        (_) async => {
          'income_minor': 0,
          'expense_minor': 0,
          'net_minor': 0,
          'savings_rate': 0,
          'income_delta_pct': 0,
          'expense_delta_pct': 0,
          'net_delta_pct': 0,
          'savings_rate_delta_pct': 0,
          'savings_rate_goal_percent': 20,
          'by_category': const [],
          'currency': 'EUR',
        },
      );
      when(
        () => apiClient.get('/dashboard/trends', query: any(named: 'query')),
      ).thenAnswer(
        (_) async => {
          'monthly_series': const [],
          'savings_series': const [],
          'currency': 'EUR',
        },
      );
      when(
        () => apiClient.get('/dashboard/habits', query: any(named: 'query')),
      ).thenAnswer((invocation) async {
        final query = invocation.namedArguments[#query] as Map<String, String>;
        return habitsJson(query['month']!);
      });

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          dashboardTodayProvider.overrideWithValue(() => DateTime(2026, 5, 14)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(dashboardHabitsProvider, (_, _) {});
      addTearDown(subscription.close);

      final first = await container.read(dashboardHabitsProvider.future);
      expect(first.month, DateTime(2026, 5));
      expect(first.daysElapsed, 14);

      await container
          .read(dashboardControllerProvider.notifier)
          .changeMonth(DateTime(2026, 3));
      final paged = await container.read(dashboardHabitsProvider.future);

      expect(paged.month, DateTime(2026, 3));
      expect(paged.daysElapsed, isNull);
      verify(
        () => apiClient.get('/dashboard/habits', query: {'month': '2026-03'}),
      ).called(1);
    });
  });
}
