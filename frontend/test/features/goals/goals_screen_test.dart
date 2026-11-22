import 'dart:convert';
import 'dart:typed_data';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_table.dart';
import 'package:bastide/core/widgets/inline_banner.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/data/goals_repository.dart';
import 'package:bastide/features/goals/domain/goal.dart';
import 'package:bastide/features/goals/domain/goal_allocation.dart';
import 'package:bastide/features/goals/presentation/goals_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/goals_fixtures.dart';

/// A 1 × 1 PNG: a picture the banner can show.
final _pngPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// The panel's own money formatting, so the expectations can't drift from the
/// locale's separators (French uses a narrow no-break space before « € »).
String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap({
  required FakeGoalsController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  List<GoalAllocation> allocations = const [],
  Uint8List? imageBytes,
}) {
  return ProviderScope(
    overrides: [
      goalsControllerProvider.overrideWith(() => controller),
      goalAllocationsProvider.overrideWith((ref, goalId) async => allocations),
      goalImageProvider.overrideWith(
        (ref, image) async => imageBytes ?? _pngPixel,
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: GoalsScreen()),
    ),
  );
}

/// The reference frame of the design, 1440 × 900, less the sidebar.
void _useDesktopSurface(WidgetTester tester, {double width = 1216}) {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _inInspector(Finder finder) => find.descendant(
  of: find.byKey(const Key('goalInspector')),
  matching: finder,
);

void main() {
  testWidgets('the summary line, the table and the first goal selected', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: specGoals(),
          savingsAccounts: [testSavingsAccount(balanceMinor: 2210000)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Réservé sur 4 objectifs'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('goalsSummaryReserved'))).data,
      _money(2445000),
    );
    expect(find.text('Épargne disponible'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('goalsSummarySavings'))).data,
      _money(2210000),
    );

    for (final header in ['Objectif', 'Échéance', 'Avancement', 'Réservé']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('goalDeadline-g1'))).data,
      'Sans échéance',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('goalDeadline-g2'))).data,
      'Juin 2028',
    );
    expect(find.text('Atteint en avril 2026'), findsWidgets);
    expect(find.text('64\u00A0%'), findsOneWidget);
    expect(
      tester.widget<RepereMeter>(find.byKey(const Key('goalMeter-g3'))).tone,
      RepereTone.done,
    );

    // The first goal is selected on arrival and fills the inspector.
    final first = tester.widget<AppTableRow>(
      find.byKey(const Key('goalRow-g1')),
    );
    expect(first.selected, isTrue);
    expect(first.twoLines, isTrue);
    expect(_inInspector(find.text("Fonds d'urgence")), findsOneWidget);
    expect(_inInspector(find.text('sur ${_money(1000000)}')), findsOneWidget);
    expect(
      _inInspector(find.text('Sans échéance · reste ${_money(360000)}')),
      findsOneWidget,
    );
    // No image: the tomettes banner with « Ajouter une image ».
    expect(find.byKey(const Key('goalBannerEmpty-g1')), findsOneWidget);
    expect(find.text('Ajouter une image'), findsOneWidget);

    expect(
      find.text(
        'Un objectif réserve une somme sur le papier. Vos comptes ne sont pas '
        'modifiés. Les images restent sur cet ordinateur.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a row shows that goal in the inspector', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(initialGoals: specGoals()),
        allocations: [
          testAllocation(goalId: 'g3', amountMinor: 50000),
          testAllocation(
            id: 'al2',
            goalId: 'g3',
            amountMinor: -10000,
            note: 'Retrait',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalRow-g3')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppTableRow>(find.byKey(const Key('goalRow-g3'))).selected,
      isTrue,
    );
    expect(_inInspector(find.text('Voyage Japon')), findsOneWidget);
    // Reached: the done repère, and no « reste » line.
    expect(
      tester
          .widget<RepereMeter>(find.byKey(const Key('goalInspectorMeter-g3')))
          .tone,
      RepereTone.done,
    );
    expect(find.byKey(const Key('goalInspectorRemaining-g3')), findsNothing);
    // Allocations: signed, coloured lines, newest first as served.
    expect(find.text('Allocations'), findsOneWidget);
    expect(find.byKey(const Key('goalAllocate')), findsOneWidget);
    expect(find.byKey(const Key('goalAllocationRow-al1')), findsOneWidget);
    expect(find.text('+${_money(50000)}'), findsOneWidget);
    expect(find.text(_money(-10000)), findsOneWidget);
  });

  testWidgets('a goal with an image shows the picture banner and Changer', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [testGoal(imageUpdatedAt: DateTime(2026, 5, 14))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalBannerImage-g1')), findsOneWidget);
    expect(find.byKey(const Key('goalThumbnail-g1')), findsOneWidget);
    expect(find.text('Changer'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('goalBannerPercent-g1')))
          .style
          ?.color,
      AppGoalBanner.title,
    );

    await tester.tap(find.byKey(const Key('goalImageChange')));
    await tester.pumpAndSettle();
    expect(find.text('Choisir une autre image'), findsOneWidget);
    expect(find.text('Retirer l’image'), findsOneWidget);
  });

  testWidgets('bytes that do not decode fall back to the tomettes banner', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [testGoal(imageUpdatedAt: DateTime(2026, 5, 14))],
        ),
        imageBytes: Uint8List.fromList([0, 1, 2]),
      ),
    );
    await tester.pumpAndSettle();

    // Never a broken image; « Changer » stays, since the goal has one.
    expect(find.byKey(const Key('goalBannerImage-g1')), findsNothing);
    expect(find.byKey(const Key('goalBannerEmpty-g1')), findsOneWidget);
    expect(find.byKey(const Key('goalImageChange')), findsOneWidget);
  });

  testWidgets('removing the image goes through the Changer menu', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(
      initialGoals: [testGoal(imageUpdatedAt: DateTime(2026, 5, 14))],
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalImageChange')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goalImageRemove')));
    await tester.pumpAndSettle();

    expect(controller.removeImageCalls, ['g1']);
  });

  testWidgets(
    'an over-funded goal clamps the repère, prints the real percent',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeGoalsController(
            initialGoals: [
              testGoal(
                targetMinor: 1000000,
                progressMinor: 1180000,
                status: GoalStatus.reached,
                reachedOn: DateTime(2026, 4, 12),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final meter = tester.widget<RepereMeter>(
        find.byKey(const Key('goalMeter-g1')),
      );
      expect(meter.fraction, 1.0);
      expect(find.text('118\u00A0%'), findsOneWidget);
    },
  );

  testWidgets('the archived link lists dimmed rows; one can be unarchived', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(
      initialGoals: [testGoal()],
      archivedGoals: [
        testGoal(id: 'g8', name: 'Vieux projet', status: GoalStatus.archived),
        testGoal(id: 'g9', name: 'Ancien voyage', status: GoalStatus.archived),
      ],
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('2 objectifs archivés'), findsOneWidget);
    expect(find.byKey(const Key('goalRow-g8')), findsNothing);

    await tester.tap(find.byKey(const Key('goalsArchivedToggle')));
    await tester.pumpAndSettle();

    final archived = tester.widget<AppTableRow>(
      find.byKey(const Key('goalRow-g8')),
    );
    expect(archived.dimmed, isTrue);
    expect(
      tester.widget<RepereMeter>(find.byKey(const Key('goalMeter-g8'))).tone,
      RepereTone.muted,
    );

    await tester.tap(find.byKey(const Key('goalRow-g8')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalUnarchive')), findsOneWidget);
    expect(find.byKey(const Key('goalArchive')), findsNothing);
    expect(find.byKey(const Key('goalAllocate')), findsNothing);

    await tester.tap(find.byKey(const Key('goalUnarchive')));
    await tester.pumpAndSettle();
    expect(controller.restoreCalls, ['g8']);
  });

  testWidgets('an allocation row deletes after a confirmation', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(initialGoals: specGoals());
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        allocations: [testAllocation(amountMinor: 30000)],
      ),
    );
    await tester.pumpAndSettle();

    final delete = find.byKey(const Key('goalAllocationDelete-al1'));
    expect(delete, findsOneWidget);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cette allocation ?'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('goalAllocationDeleteLead')))
          .data,
      'Le montant mis de côté baisse de ${_money(30000)}. '
      'Vos comptes ne sont pas modifiés.',
    );

    await tester.tap(find.byKey(const Key('goalAllocationDeleteSubmit')));
    await tester.pumpAndSettle();

    expect(controller.deleteAllocationCalls, [('g1', 'al1')]);
    expect(find.byKey(const Key('goalAllocationDeleteModal')), findsNothing);
  });

  testWidgets('deleting a withdrawal says the saved amount goes back up', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(initialGoals: specGoals()),
        locale: const Locale('en'),
        allocations: [testAllocation(amountMinor: -10000, note: null)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalAllocationDelete-al1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete this allocation?'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('goalAllocationDeleteLead')))
          .data,
      'The saved amount goes back up by ${_money(10000, locale: 'en')}. '
      'Your accounts are not changed.',
    );
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(initialGoals: specGoals());
    await tester.pumpWidget(
      _wrap(controller: controller, allocations: [testAllocation()]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalAllocationDelete-al1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goalAllocationDeleteCancel')));
    await tester.pumpAndSettle();

    expect(controller.deleteAllocationCalls, isEmpty);
    expect(find.byKey(const Key('goalAllocationDeleteModal')), findsNothing);
    expect(find.byKey(const Key('goalAllocationRow-al1')), findsOneWidget);
  });

  testWidgets('an archived goal offers no delete on its allocations', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [testGoal(status: GoalStatus.archived)],
        ),
        allocations: [testAllocation()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalAllocationRow-al1')), findsOneWidget);
    expect(find.byKey(const Key('goalAllocationDelete-al1')), findsNothing);
  });

  testWidgets('archiving goes through the inspector', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(initialGoals: specGoals());
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalArchive')));
    await tester.pumpAndSettle();

    expect(controller.archiveCalls, ['g1']);
    expect(find.text('1 objectif archivé'), findsOneWidget);
  });

  testWidgets('over-allocation is neutral, states the delta, and closes', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [
            testGoal(progressMinor: 2445000, targetMinor: 3000000),
          ],
          savingsAccounts: [testSavingsAccount(balanceMinor: 2210000)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final banner = find.byKey(const Key('goalsOverAllocationBanner'));
    final widget = tester.widget<InlineBanner>(banner);
    expect(widget.tone, BannerTone.info);
    expect(
      widget.message,
      'Vous avez réservé ${_money(235000)} de plus que le total de vos '
      'comptes d’épargne.',
    );

    await tester.tap(
      find.descendant(of: banner, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalsOverAllocationBanner')), findsNothing);
    expect(find.byKey(const Key('goalRow-g1')), findsOneWidget);
  });

  testWidgets('without a savings account the figure is a dash, no banner', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [
            testGoal(progressMinor: 2445000, targetMinor: 3000000),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('goalsSummarySavings'))).data,
      '—',
    );
    expect(find.byKey(const Key('goalsOverAllocationBanner')), findsNothing);
  });

  testWidgets('English copy and formats', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(initialGoals: specGoals()),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reserved across 4 goals'), findsOneWidget);
    expect(find.text('Reached in April 2026'), findsWidgets);
    expect(find.text('No deadline'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    testWidgets('renders in the $name theme with the sidebar collapsed', (
      tester,
    ) async {
      // 1440 less the 56 px collapsed sidebar.
      _useDesktopSurface(tester, width: 1384);
      await tester.pumpWidget(
        _wrap(
          controller: FakeGoalsController(
            initialGoals: specGoals(),
            savingsAccounts: [testSavingsAccount(balanceMinor: 2210000)],
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('goalInspector')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the empty state is a single pane with the one action', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeGoalsController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalsEmptyState')), findsOneWidget);
    expect(find.text('Aucun objectif'), findsOneWidget);
    expect(find.byKey(const Key('goalsEmptyAddButton')), findsOneWidget);
    expect(find.byKey(const Key('goalInspector')), findsNothing);
  });

  testWidgets('a failed load says so and offers a retry', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeGoalsController(loadError: Exception('down'))),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de charger vos objectifs. Rien n’a été modifié.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('goalsRetryButton')), findsOneWidget);
  });
}
