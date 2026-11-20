import 'dart:async';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/app_card.dart';
import 'package:bastide/core/widgets/status_text.dart';
import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/domain/networth_summary.dart';
import 'package:bastide/features/networth/presentation/composition_breakdown.dart';
import 'package:bastide/features/networth/presentation/networth_screen.dart';
import 'package:bastide/features/properties/application/properties_controller.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

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
  ThemeData? theme,
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
      theme: theme ?? AppTheme.dark,
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

/// The text inside the widget at [key]: an [AmountText], a [StatusText], a
/// note.
Text _inner(WidgetTester tester, String key) => tester.widget<Text>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
);

class _PendingNetworth extends FakeNetworthController {
  @override
  Future<NetWorthSummary> build() => Completer<NetWorthSummary>().future;
}

void main() {
  group('equation line', () {
    testWidgets('reads assets minus liabilities equals net worth, neutral', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final value = _inner(tester, 'networthValue');
      expect(value.data, _money(28267079));
      expect(value.style!.color, AppColors.dark.text);
      expect(value.style!.fontSize, 40);

      final assets = _inner(tester, 'networthAssets');
      expect(assets.data, _money(51680000));
      expect(assets.style!.fontSize, 28);
      expect(
        _text(tester, 'networthAssetsCaption'),
        'Comptes ${_money(2430000)} · Biens ${_money(49250000)}',
      );
      expect(_inner(tester, 'networthLiabilities').data, _money(23412921));
      expect(
        _text(tester, 'networthLiabilitiesCaption'),
        '2 crédits, capital restant dû',
      );
      for (final operator in const ['−', '=']) {
        final glyph = tester.widget<Text>(find.text(operator));
        expect(glyph.style!.color, AppColors.dark.textTertiary);
      }
      expect(find.text('Patrimoine net'), findsNWidgets(2));

      // Read left to right: Actif, then Passif. (The test font draws every
      // glyph a full em wide, so the net worth may wrap here.)
      double left(String key) => tester.getTopLeft(find.byKey(Key(key))).dx;
      expect(left('networthAssets'), lessThan(left('networthLiabilities')));
    });

    testWidgets('reads the same in English', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Assets'), findsOneWidget);
      expect(find.text('Liabilities'), findsOneWidget);
      expect(find.text('Net worth'), findsNWidgets(2));
      expect(
        _text(tester, 'networthAssetsCaption'),
        'Accounts ${_money(2430000, locale: 'en')} · '
        'Properties ${_money(49250000, locale: 'en')}',
      );
      expect(
        _text(tester, 'networthLiabilitiesCaption'),
        '2 loans, outstanding principal',
      );
      expect(
        _inner(tester, 'networthDelta').data,
        '${_money(147778, locale: 'en', sign: true)} since April',
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

        final painted = _inner(tester, 'networthValue');
        expect(painted.data, contains('−'));
        expect(painted.data, isNot(contains('-')));
        expect(painted.data, _money(-20982921, locale: locale));
        expect(painted.style!.color, AppColors.dark.text);
      });
    }

    testWidgets('a part that is zero is left out of the assets caption', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          networth: FakeNetworthController(summary: testNoPropertySummary()),
          properties: FakePropertiesController(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _text(tester, 'networthAssetsCaption'),
        'Comptes ${_money(2430000)}',
      );
    });

    for (final (delta, icon) in const [
      (147778, LucideIcons300.trendingUp),
      (-147778, LucideIcons300.trendingDown),
    ]) {
      testWidgets('the month change is a neutral status ($delta)', (
        tester,
      ) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(
            networth: FakeNetworthController(
              summary: testNetworthSummary(monthDeltaMinor: delta),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final status = tester.widget<StatusText>(
          find.byKey(const Key('networthDelta')),
        );
        expect(status.tone, StatusTone.neutral);
        expect(status.icon, icon);
        final label = _inner(tester, 'networthDelta');
        expect(label.data, '${_money(delta, sign: true)} depuis avril');
        expect(label.style!.color, AppColors.dark.textSecondary);
      });
    }

    testWidgets('no month change without a previous month', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          networth: FakeNetworthController(
            summary: testNetworthSummary(monthDeltaMinor: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('networthDelta')), findsNothing);
    });
  });

  group('composition', () {
    testWidgets('lists the slices by descending amount, hues by rank', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      const order = [
        'property-primary_residence',
        'property-rental',
        'account-savings',
        'account-checking',
      ];
      final tops = [
        for (final key in order)
          tester.getTopLeft(find.byKey(Key('compositionRow-$key'))).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));

      for (final (rank, key) in order.indexed) {
        final segment = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(Key('compositionSegment-$key')),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          (segment.decoration as BoxDecoration).color,
          CategoryColors.dark.forRank(rank),
        );
      }
      expect(
        tester.getSize(find.byKey(const Key('compositionBar'))).height,
        AppChart.compositionBarHeight,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('compositionRow-property-rental')),
          matching: find.text('Locatif, part détenue'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const Key('compositionRow-property-primary_residence'),
          ),
          matching: find.text(formatCompositionShare(8130, 'fr')),
        ),
        findsOneWidget,
      );
      expect(
        _text(tester, 'compositionPartNote-p2'),
        'Un bien compte pour la part détenue : Studio Villeurbanne, '
        '${_money(7250000)} sur ${_money(14500000)}.',
      );
      expect(find.byKey(const Key('compositionPartNote-p1')), findsNothing);
    });

    testWidgets('the part note reads in English', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(
        _text(tester, 'compositionPartNote-p2'),
        'A property counts for the held share: Studio Villeurbanne, '
        '${_money(7250000, locale: 'en')} of '
        '${_money(14500000, locale: 'en')}.',
      );
    });

    testWidgets('no property: no property row in the composition', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          networth: FakeNetworthController(summary: testNoPropertySummary()),
          properties: FakePropertiesController(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('compositionSegment-account-checking')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('compositionRow-property-rental')),
        findsNothing,
      );
    });
  });

  group('notes', () {
    testWidgets('say what is not counted, under « À savoir »', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('À savoir'), findsOneWidget);
      expect(find.text('À SAVOIR'), findsNothing);
      expect(
        _inner(tester, 'networthNoteGoals').data,
        'Les objectifs réservent de l’argent déjà présent sur un compte. '
        'Ils ne sont pas comptés une seconde fois.',
      );
      expect(
        _inner(tester, 'networthNoteSubscriptions').data,
        'Un abonnement est une dépense à venir, pas une dette due '
        'aujourd’hui.',
      );
      expect(find.byKey(const Key('networthNoteHeldFlat')), findsOneWidget);
    });

    testWidgets('read in English', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Good to know'), findsOneWidget);
    });
  });

  testWidgets('sections, not cards: nothing on the page is framed', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(AppCard), findsNothing);
    expect(find.byKey(const Key('networthViewSwitch')), findsNothing);
  });

  testWidgets('renders in the light theme with its tokens', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(theme: AppTheme.light));
    await tester.pumpAndSettle();

    expect(_inner(tester, 'networthValue').style!.color, AppColors.light.text);
    expect(
      _inner(tester, 'networthDelta').style!.color,
      AppColors.light.textSecondary,
    );
  });

  testWidgets('renders with the sidebar expanded, at 1440 − 224 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440 - AppSizes.sidebar, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('networthPage')), findsOneWidget);
  });

  testWidgets('the title-bar control is the secondary « Nouveau bien »', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final button = tester.widget<AppButton>(
      find.byKey(const Key('addPropertyButton')),
    );
    expect(button.variant, AppButtonVariant.secondary);
    expect(button.icon, LucideIcons300.plus);
    expect(button.label, 'Nouveau bien');
  });

  testWidgets('nothing at all shows the empty state', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        networth: FakeNetworthController(summary: testEmptySummary()),
        properties: FakePropertiesController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('networthEmptyState')), findsOneWidget);
    expect(find.text('Aucun compte, bien ou crédit'), findsOneWidget);
    expect(find.text('Aller aux imports'), findsOneWidget);
    expect(find.byKey(const Key('networthEmptyAddProperty')), findsOneWidget);
    expect(find.byKey(const Key('networthPage')), findsNothing);
    expect(find.byKey(const Key('networthErrorText')), findsNothing);
  });

  testWidgets('loading shows the silhouette', (tester) async {
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
