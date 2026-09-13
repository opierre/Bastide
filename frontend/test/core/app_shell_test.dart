import 'package:finstride/core/navigation/sidebar_controller.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/app_shell.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_dashboard_controller.dart';

Widget _shell({
  required String path,
  Locale locale = const Locale('fr'),
  bool collapsed = false,
}) {
  return ProviderScope(
    overrides: [
      if (collapsed)
        sidebarCollapsedProvider.overrideWith(FakeCollapsedSidebar.new),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(
        currentPath: path,
        onNavigate: (_) {},
        child: const SizedBox.expand(),
      ),
    ),
  );
}

/// The frame the layout invariant is measured against (`docs/design/00`).
void _useFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _inSidebar(Finder finder) =>
    find.descendant(of: find.byKey(const Key('appNavRail')), matching: finder);

Finder _inTopBar(Finder finder) =>
    find.descendant(of: find.byKey(const Key('appTopBar')), matching: finder);

const _patrimoine = [
  ('/mortgages', NavGlyph.house),
  ('/simulations', NavGlyph.calculator),
  ('/networth', NavGlyph.pie),
];

void main() {
  testWidgets(
    'the Patrimoine group sits after Gestion, before the pinned Paramètres, in order',
    (tester) async {
      _useFrame(tester);
      await tester.pumpWidget(_shell(path: '/dashboard'));
      await tester.pumpAndSettle();

      double top(String text) =>
          tester.getTopLeft(_inSidebar(find.text(text))).dy;

      const order = [
        'Objectifs',
        'PATRIMOINE',
        'Crédits',
        'Simulateur',
        'Synthèse',
        'Paramètres',
        'Données 100 % locales',
      ];
      for (var i = 1; i < order.length; i++) {
        expect(top(order[i]), greaterThan(top(order[i - 1])), reason: order[i]);
      }
      expect(find.byType(NavGlyphIcon), findsNWidgets(3));
      expect(_inSidebar(find.text('Impôts')), findsNothing);
    },
  );

  for (final (path, glyph) in _patrimoine) {
    testWidgets('$path resolves as the active item with its filled glyph', (
      tester,
    ) async {
      _useFrame(tester);
      await tester.pumpWidget(_shell(path: path));
      await tester.pumpAndSettle();

      final filled = tester
          .widgetList<NavGlyphIcon>(find.byType(NavGlyphIcon))
          .where((icon) => icon.filled)
          .toList();
      expect(filled, hasLength(1));
      expect(filled.single.glyph, glyph);
    });
  }

  testWidgets(
    'each route puts its title and descriptor in the top bar, in fr',
    (tester) async {
      _useFrame(tester);
      const expected = {
        '/mortgages': ('Crédits', 'Vos emprunts, leur coût et votre capacité'),
        '/simulations': ('Simulateur', "Ce qu'un nouveau crédit changerait"),
        '/networth': ('Synthèse', 'Ce que vous possédez, ce que vous devez'),
      };
      for (final MapEntry(key: path, value: (title, subtitle))
          in expected.entries) {
        await tester.pumpWidget(_shell(path: path));
        await tester.pumpAndSettle();

        expect(_inTopBar(find.text(title)), findsOneWidget, reason: path);
        expect(_inTopBar(find.text(subtitle)), findsOneWidget, reason: path);
      }
    },
  );

  testWidgets(
    'en labels, with "Net worth" rather than "Overview" for /networth',
    (tester) async {
      _useFrame(tester);
      await tester.pumpWidget(
        _shell(path: '/networth', locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      for (final label in ['WEALTH', 'Loans', 'Simulator', 'Net worth']) {
        expect(_inSidebar(find.text(label)), findsOneWidget, reason: label);
      }
      expect(_inTopBar(find.text('Net worth')), findsOneWidget);
      expect(
        _inTopBar(find.text('What you own, what you owe')),
        findsOneWidget,
      );
      // "Overview" stays the group label of the first section only.
      expect(find.text('OVERVIEW'), findsOneWidget);
    },
  );

  testWidgets(
    'the collapsed rail carries the three glyphs and a hairline at each group boundary',
    (tester) async {
      _useFrame(tester);
      await tester.pumpWidget(_shell(path: '/simulations', collapsed: true));
      await tester.pumpAndSettle();

      expect(find.byType(NavGlyphIcon), findsNWidgets(3));
      expect(find.text('PATRIMOINE'), findsNothing);
      // Aperçu/Gestion, Gestion/Patrimoine, and one before Paramètres.
      expect(find.byType(NavRailSeparator), findsNWidgets(3));
      final hairline = tester.getSize(
        find
            .descendant(
              of: find.byType(NavRailSeparator).first,
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(hairline, const Size(NavRailSeparator.width, 1));
    },
  );

  for (final collapsed in [false, true]) {
    testWidgets(
      'at 1440×900 the ${collapsed ? 'collapsed' : 'expanded'} sidebar stack does not scroll',
      (tester) async {
        _useFrame(tester);
        await tester.pumpWidget(
          _shell(path: '/networth', collapsed: collapsed),
        );
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          _inSidebar(find.byType(Scrollable)),
        );
        expect(scrollable.position.maxScrollExtent, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
