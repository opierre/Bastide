import 'dart:async';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/domain/networth_summary.dart';
import 'package:bastide/features/networth/presentation/composition_breakdown.dart';
import 'package:bastide/features/networth/presentation/networth_screen.dart';
import 'package:bastide/features/networth/presentation/networth_summary_card.dart';
import 'package:bastide/features/properties/application/properties_controller.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/networth_fixtures.dart';
import '../../support/properties_fixtures.dart';

String _money(int amountMinor, {String locale = 'fr', bool sign = false}) =>
    formatAmount(
      amountMinor: amountMinor,
      currency: 'EUR',
      locale: locale,
      showPositiveSign: sign,
    );

Widget _wrap({
  FakeNetworthController? networth,
  FakePropertiesController? properties,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      networthControllerProvider.overrideWith(
        () => networth ?? FakeNetworthController(),
      ),
      propertiesControllerProvider.overrideWith(
        () =>
            properties ??
            FakePropertiesController(
              initialProperties: [testProperty(), testStudio()],
            ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            NetworthTopBarActions(),
            Expanded(child: NetworthScreen()),
          ],
        ),
      ),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

/// The rendered text of an [AmountText], with the style it was painted in.
Text _amount(WidgetTester tester, String key) => tester.widget<Text>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
);

String _segmentLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('networthPropertiesSegment')),
        matching: find.byType(Text),
      ),
    )
    .data!;

class _PendingNetworth extends FakeNetworthController {
  @override
  Future<NetWorthSummary> build() => Completer<NetWorthSummary>().future;
}

void main() {
  group('summary figures', () {
    testWidgets('render as returned, neutral, formatted in French', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final value = tester.widget<AmountText>(
        find.byKey(const Key('networthValue')),
      );
      expect(value.amountMinor, 28267079);
      expect(value.colorize, isFalse);
      final painted = _amount(tester, 'networthValue');
      expect(painted.data, _money(28267079));
      expect(painted.style!.color, AppColors.textPrimary);

      expect(_amount(tester, 'networthAssets').data, _money(51680000));
      expect(
        _text(tester, 'networthAssetsCaption'),
        'Comptes ${_money(2430000)} · Biens ${_money(49250000)}',
      );
      expect(_amount(tester, 'networthLiabilities').data, _money(23412921));
      expect(
        _text(tester, 'networthLiabilitiesCaption'),
        '2 crédits · capital restant dû',
      );
      expect(_segmentLabel(tester), 'Biens (2)');
    });

    testWidgets('render the same figures in English', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(
        _amount(tester, 'networthValue').data,
        _money(28267079, locale: 'en'),
      );
      expect(
        _text(tester, 'networthAssetsCaption'),
        'Accounts ${_money(2430000, locale: 'en')} · '
        'Properties ${_money(49250000, locale: 'en')}',
      );
      expect(
        _text(tester, 'networthLiabilitiesCaption'),
        '2 loans · outstanding principal',
      );
      expect(_segmentLabel(tester), 'Properties (2)');
      expect(
        find.text('Deliberately not counted'.toUpperCase()),
        findsOneWidget,
      );
    });

    for (final locale in const ['fr', 'en']) {
      testWidgets('a negative net worth keeps the neutral ink ($locale)', (
        tester,
      ) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(
            locale: Locale(locale),
            networth: FakeNetworthController(summary: testNoPropertySummary()),
            properties: FakePropertiesController(),
          ),
        );
        await tester.pumpAndSettle();

        final painted = _amount(tester, 'networthValue');
        expect(painted.data, contains('−'));
        expect(painted.data, isNot(contains('-')));
        expect(painted.data, _money(-20982921, locale: locale));
        expect(painted.style!.color, AppColors.textPrimary);
      });
    }
  });

  group('month delta pill', () {
    for (final (delta, turns) in const [(147778, 0), (-147778, 2)]) {
      testWidgets('is iris for a delta of $delta', (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(
            networth: FakeNetworthController(
              summary: testNetworthSummary(monthDeltaMinor: delta),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pill = tester.widget<Container>(
          find.byKey(const Key('networthDeltaPill')),
        );
        expect(
          (pill.decoration! as BoxDecoration).color,
          NetworthDeltaPill.fill,
        );
        expect(
          tester
              .widget<RotatedBox>(
                find.byKey(const Key('networthDeltaTriangle')),
              )
              .quarterTurns,
          turns,
        );
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('networthDeltaTriangle')),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.color, AppColors.iris);
        final amount = tester.widget<Text>(
          find.byKey(const Key('networthDeltaAmount')),
        );
        expect(amount.data, _money(delta, sign: true));
        expect(amount.style!.color, AppColors.iris);
        expect(
          _text(tester, 'networthDeltaCaption'),
          'vs avril 2026 — valeur des biens inchangée',
        );
      });
    }

    testWidgets('is absent without a previous month', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          networth: FakeNetworthController(
            summary: testNetworthSummary(monthDeltaMinor: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('networthDeltaPill')), findsNothing);
    });
  });

  testWidgets('the composition is a stacked strip with its held-share foot', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compositionStrip')), findsOneWidget);
    for (final key in const [
      'account-checking',
      'account-savings',
      'property-primary_residence',
      'property-rental',
    ]) {
      expect(find.byKey(Key('compositionSegment-$key')), findsOneWidget);
      expect(find.byKey(Key('compositionRow-$key')), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('compositionRow-property-rental')),
        matching: find.text('Locatif (part détenue)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('compositionRow-property-primary_residence')),
        matching: find.text(formatCompositionShare(8130, 'fr')),
      ),
      findsOneWidget,
    );
    expect(
      _text(tester, 'compositionFoot'),
      'Les biens comptent pour la part détenue seulement '
      '(Studio Villeurbanne : ${_money(7250000)} sur ${_money(14500000)}).',
    );
    expect(find.byKey(const Key('compositionInvite')), findsNothing);
  });

  testWidgets('the exclusions are stated in the panel', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('VOLONTAIREMENT NON COMPTÉ'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('exclusionGoals')),
        matching: find.text('Objectifs'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('exclusionSubscriptions')),
        matching: find.text(
          'Un prélèvement récurrent est une dépense à venir, pas une dette due aujourd\'hui.',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'no property: the summary runs on accounts and loans with an invite plate',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          networth: FakeNetworthController(summary: testNoPropertySummary()),
          properties: FakePropertiesController(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('networthViewSwitch')), findsOneWidget);
      expect(_segmentLabel(tester), 'Biens (0)');
      expect(
        _text(tester, 'networthAssetsCaption'),
        'Comptes ${_money(2430000)} · aucun bien déclaré',
      );
      expect(find.byKey(const Key('compositionInvite')), findsOneWidget);
      expect(find.byKey(const Key('compositionFoot')), findsNothing);
      expect(
        find.byKey(const Key('compositionSegment-account-checking')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('compositionSegment-property-rental')),
        findsNothing,
      );
      expect(find.byKey(const Key('networthExclusions')), findsOneWidget);
    },
  );

  testWidgets('nothing at all shows the empty state without the switch', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        networth: FakeNetworthController(summary: testEmptySummary()),
        properties: FakePropertiesController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('networthEmptyState')), findsOneWidget);
    expect(find.text('Rien à additionner pour l\'instant'), findsOneWidget);
    expect(find.byKey(const Key('networthEmptyImport')), findsOneWidget);
    expect(find.byKey(const Key('networthEmptyAddProperty')), findsOneWidget);
    expect(find.byKey(const Key('networthViewSwitch')), findsNothing);
    expect(find.byKey(const Key('networthErrorText')), findsNothing);
  });

  testWidgets('loading shows the skeleton', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(networth: _PendingNetworth()));
    await tester.pump();

    expect(find.byKey(const Key('networthLoading')), findsOneWidget);
  });

  testWidgets('a load failure shows the retry state', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(networth: FakeNetworthController(loadError: Exception('offline'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('networthErrorText')), findsOneWidget);
    expect(find.byKey(const Key('networthRetryButton')), findsOneWidget);
  });
}
