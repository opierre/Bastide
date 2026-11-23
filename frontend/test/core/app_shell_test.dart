import 'package:bastide/core/navigation/sidebar_controller.dart';
import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/storage/ui_preferences.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_shell.dart';
import 'package:bastide/core/window/window_providers.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/transactions/application/review_count_provider.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../support/fake_dashboard_controller.dart';
import '../support/fake_ui_preferences.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

Widget _shell({
  required String path,
  Locale locale = const Locale('fr'),
  bool collapsed = false,
  int reviewCount = 0,
  ThemeData? theme,
  TopBarTitleBuilder? titleBuilder,
  TopBarActionsBuilder? actionsBuilder,
  ValueChanged<String>? onNavigate,
  bool systemWindowButtons = false,
}) {
  return ProviderScope(
    overrides: [
      uiPreferencesStoreProvider.overrideWithValue(FakeUiPreferencesStore()),
      if (collapsed)
        sidebarCollapsedProvider.overrideWith(FakeCollapsedSidebar.new),
      currentUserProvider.overrideWithValue(_user),
      reviewCountProvider.overrideWith((ref) async => reviewCount),
      systemWindowButtonsProvider.overrideWithValue(systemWindowButtons),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(
        currentPath: path,
        onNavigate: onNavigate ?? (_) {},
        titleBuilder: titleBuilder,
        actionsBuilder: actionsBuilder,
        child: const SizedBox.expand(key: Key('content')),
      ),
    ),
  );
}

/// The frame the layout invariant is measured against (`docs/design/00` §5).
void _useFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _inSidebar(Finder finder) =>
    find.descendant(of: find.byKey(const Key('appNavRail')), matching: finder);

Finder _inTopBar(Finder finder) =>
    find.descendant(of: find.byKey(const Key('appTopBar')), matching: finder);

double _sidebarWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('appNavRail'))).width;

TextStyle _labelStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(_inSidebar(find.text(label))).style!;

void main() {
  testWidgets('sidebar 224 px and title bar 48 px, in both themes', (
    tester,
  ) async {
    _useFrame(tester);
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      await tester.pumpWidget(_shell(path: '/dashboard', theme: theme));
      await tester.pumpAndSettle();

      expect(_sidebarWidth(tester), AppSizes.sidebar);
      expect(
        tester.getSize(find.byKey(const Key('appTopBar'))).height,
        AppSizes.titleBar,
      );
      expect(find.byKey(const Key('appBottomBar')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('three groups in sentence case, Placements under Patrimoine, '
      'then Paramètres, the user row and the privacy line', (tester) async {
    _useFrame(tester);
    await tester.pumpWidget(_shell(path: '/dashboard'));
    await tester.pumpAndSettle();

    double top(String text) =>
        tester.getTopLeft(_inSidebar(find.text(text))).dy;

    const order = [
      'Bastide',
      "Vue d’ensemble",
      'Tableau de bord',
      'Comptes',
      'Transactions',
      'Gestion',
      'Imports',
      'Catégories',
      'Abonnements',
      'Objectifs',
      'Patrimoine',
      'Crédits',
      'Placements',
      'Simulateur',
      'Synthèse',
      'Paramètres',
      'Ada',
      'Données locales',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i]), greaterThan(top(order[i - 1])), reason: order[i]);
    }
    // No uppercase labels in v2.
    expect(_inSidebar(find.text('PATRIMOINE')), findsNothing);
    // Paramètres sits at the foot, under the empty stretch.
    expect(top('Paramètres'), greaterThan(700));
  });

  testWidgets('the active item takes the hover ground and weight 500 only', (
    tester,
  ) async {
    _useFrame(tester);
    await tester.pumpWidget(_shell(path: '/accounts/acc-1'));
    await tester.pumpAndSettle();

    final colors = AppTheme.dark.extension<AppColors>()!;
    // A page beneath a destination keeps it selected.
    expect(_labelStyle(tester, 'Comptes').fontWeight, FontWeight.w500);
    expect(_labelStyle(tester, 'Comptes').color, colors.text);
    expect(_labelStyle(tester, 'Transactions').fontWeight, FontWeight.w400);
    expect(_labelStyle(tester, 'Transactions').color, colors.textSecondary);

    final ground = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('nav/accounts')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((ground.decoration! as BoxDecoration).color, colors.hover);
  });

  testWidgets('Transactions carries the review count, hidden at zero', (
    tester,
  ) async {
    _useFrame(tester);
    await tester.pumpWidget(_shell(path: '/dashboard', reviewCount: 12));
    await tester.pumpAndSettle();

    final count = find.byKey(const Key('sidebarReviewCount'));
    expect(
      find.descendant(
        of: find.byKey(const Key('nav/transactions')),
        matching: count,
      ),
      findsOneWidget,
    );
    expect(tester.widget<Text>(count).data, '12');

    // A fresh scope: overrides are read once per container.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_shell(path: '/dashboard'));
    await tester.pumpAndSettle();
    expect(count, findsNothing);
  });

  testWidgets('the title bar shows the title and no subtitle', (tester) async {
    _useFrame(tester);
    const expected = {
      '/mortgages': ('Crédits', 'Vos emprunts, leur coût et votre capacité'),
      '/simulations': ('Simulateur', "Ce qu’un nouveau crédit changerait"),
      '/networth': ('Synthèse', 'Ce que vous possédez, ce que vous devez'),
      '/investments': ('Placements', null),
      '/settings': ('Paramètres', null),
    };
    for (final MapEntry(key: path, value: (title, tagline))
        in expected.entries) {
      await tester.pumpWidget(_shell(path: path));
      await tester.pumpAndSettle();

      final titleText = _inTopBar(find.byKey(const Key('titleBarTitle')));
      expect(tester.widget<Text>(titleText).data, title, reason: path);
      if (tagline != null) expect(find.text(tagline), findsNothing);
      // One line of text in the bar: the title.
      expect(_inTopBar(find.byType(Text)), findsOneWidget, reason: path);
    }
  });

  testWidgets('a crumb leads back to the parent, then the title', (
    tester,
  ) async {
    _useFrame(tester);
    var crumbTaps = 0;
    await tester.pumpWidget(
      _shell(
        path: '/accounts/acc-1',
        titleBuilder: (_) => TitleBarTitle(
          title: 'Compte courant',
          crumb: TitleBarCrumb(label: 'Comptes', onTap: () => crumbTaps++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final crumb = _inTopBar(find.byKey(const Key('titleBarCrumb')));
    final title = _inTopBar(find.text('Compte courant'));
    expect(tester.getTopLeft(crumb).dx, lessThan(tester.getTopLeft(title).dx));
    expect(_inTopBar(find.text('/')), findsOneWidget);

    await tester.tap(crumb);
    expect(crumbTaps, 1);
  });

  testWidgets('contextual controls sit at the right, 8 px apart', (
    tester,
  ) async {
    _useFrame(tester);
    await tester.pumpWidget(
      _shell(
        path: '/dashboard',
        actionsBuilder: (_) => const [
          SizedBox(key: Key('a'), width: 60, height: AppSizes.button),
          SizedBox(key: Key('b'), width: 60, height: AppSizes.button),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byKey(const Key('appTopBar')));
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    expect(b.left - a.right, AppSpacing.sm);
    // Then 8 px to the window controls, which meet the right edge.
    expect(bar.right - b.right, AppSpacing.sm + 3 * AppSizes.windowControl);
  });

  testWidgets('macOS: no window controls, the bar keeps its 24 px padding', (
    tester,
  ) async {
    _useFrame(tester);
    await tester.pumpWidget(
      _shell(
        path: '/dashboard',
        systemWindowButtons: true,
        actionsBuilder: (_) => const [
          SizedBox(key: Key('a'), width: 60, height: AppSizes.button),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byKey(const Key('appTopBar')));
    final a = tester.getRect(find.byKey(const Key('a')));
    expect(bar.right - a.right, AppSpacing.lg);
    expect(find.byKey(const Key('windowControls')), findsNothing);
  });

  testWidgets('Ctrl+B collapses to the 56 px icon rail and back', (
    tester,
  ) async {
    _useFrame(tester);
    await tester.pumpWidget(_shell(path: '/dashboard'));
    await tester.pumpAndSettle();
    expect(_sidebarWidth(tester), AppSizes.sidebar);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(_sidebarWidth(tester), AppSizes.sidebarCollapsed);
    // Icons only; the label moves to a tooltip.
    expect(_inSidebar(find.text('Comptes')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('nav/accounts')),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Comptes'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_sidebarWidth(tester), AppSizes.sidebar);
  });

  testWidgets('the collapse button sits just above Paramètres', (tester) async {
    _useFrame(tester);
    await tester.pumpWidget(_shell(path: '/dashboard'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('sidebarCollapseToggle'));
    final settings = find.byKey(const Key('nav/settings'));
    expect(
      tester.getRect(toggle).bottom,
      moreOrLessEquals(tester.getRect(settings).top, epsilon: 0.5),
    );
    expect(_inSidebar(find.text('Replier')), findsOneWidget);
    expect(
      find.descendant(
        of: toggle,
        matching: find.byIcon(LucideIcons300.panelLeftClose),
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Replier la barre latérale (Ctrl+B)'),
      findsOneWidget,
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(_sidebarWidth(tester), AppSizes.sidebarCollapsed);
    expect(_inSidebar(find.text('Replier')), findsNothing);
    expect(
      find.descendant(
        of: toggle,
        matching: find.byIcon(LucideIcons300.panelLeftOpen),
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Déplier la barre latérale (Ctrl+B)'),
      findsOneWidget,
    );
  });

  testWidgets('the collapse button speaks English', (tester) async {
    _useFrame(tester);
    await tester.pumpWidget(
      _shell(path: '/dashboard', locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(_inSidebar(find.text('Collapse')), findsOneWidget);
    expect(find.byTooltip('Collapse the sidebar (Ctrl+B)'), findsOneWidget);
  });

  testWidgets('the collapsed foot keeps the avatar and the lock', (
    tester,
  ) async {
    _useFrame(tester);
    await tester.pumpWidget(_shell(path: '/simulations', collapsed: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('userMenuButton')), findsOneWidget);
    expect(find.byTooltip('Ada'), findsOneWidget);
    expect(find.byTooltip('Données locales'), findsOneWidget);
    expect(_inSidebar(find.text('Vue d’ensemble')), findsNothing);
  });

  testWidgets('the user row opens Paramètres and Se déconnecter', (
    tester,
  ) async {
    _useFrame(tester);
    final visited = <String>[];
    await tester.pumpWidget(
      _shell(path: '/dashboard', onNavigate: visited.add),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('userMenuButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('userMenuLogoutItem')), findsOneWidget);

    await tester.tap(find.byKey(const Key('userMenuSettingsItem')));
    await tester.pumpAndSettle();
    expect(visited, ['/settings']);
  });

  testWidgets('en labels', (tester) async {
    _useFrame(tester);
    await tester.pumpWidget(
      _shell(path: '/investments', locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Overview',
      'Wealth',
      'Loans',
      'Investments',
      'Net worth',
      'Settings',
      'Local data',
    ]) {
      expect(_inSidebar(find.text(label)), findsOneWidget, reason: label);
    }
    expect(_inTopBar(find.text('Investments')), findsOneWidget);
  });

  for (final collapsed in [false, true]) {
    testWidgets(
      'at 1440×900 the ${collapsed ? 'collapsed' : 'expanded'} sidebar does not scroll',
      (tester) async {
        _useFrame(tester);
        await tester.pumpWidget(
          _shell(path: '/networth', collapsed: collapsed, reviewCount: 3),
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
