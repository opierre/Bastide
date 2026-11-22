import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/storage/ui_preferences.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_shell.dart';
import 'package:bastide/core/widgets/brand_mark.dart';
import 'package:bastide/core/widgets/window_controls.dart';
import 'package:bastide/core/window/window_chrome.dart';
import 'package:bastide/core/window/window_providers.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/transactions/application/review_count_provider.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ui_preferences.dart';
import '../support/fake_window_chrome.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

Widget _app({
  required FakeWindowChrome chrome,
  required Widget home,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  bool systemWindowButtons = false,
}) {
  return ProviderScope(
    overrides: [
      uiPreferencesStoreProvider.overrideWithValue(FakeUiPreferencesStore()),
      currentUserProvider.overrideWithValue(_user),
      reviewCountProvider.overrideWith((ref) async => 0),
      windowChromeProvider.overrideWithValue(chrome),
      systemWindowButtonsProvider.overrideWithValue(systemWindowButtons),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Widget _shell({
  required FakeWindowChrome chrome,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  bool systemWindowButtons = false,
}) => _app(
  chrome: chrome,
  locale: locale,
  theme: theme,
  systemWindowButtons: systemWindowButtons,
  home: AppShell(
    currentPath: '/dashboard',
    onNavigate: (_) {},
    actionsBuilder: (_) => const [
      SizedBox(key: Key('action'), width: 60, height: AppSizes.button),
    ],
    child: const SizedBox.expand(),
  ),
);

void _useFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _minimize = Key('windowMinimize');
const _maximize = Key('windowMaximize');
const _close = Key('windowClose');

Color _ground(WidgetTester tester, Key key) => tester
    .widget<ColoredBox>(
      find.descendant(of: find.byKey(key), matching: find.byType(ColoredBox)),
    )
    .color;

Icon _icon(WidgetTester tester, Key key) => tester.widget<Icon>(
  find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
);

/// One mouse per test, parked in a corner of the content.
Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(700, 500));
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _hover(WidgetTester tester, TestGesture mouse, Key key) async {
  await mouse.moveTo(tester.getCenter(find.byKey(key)));
  await tester.pump();
}

/// Lets the window's state reach the widgets: the stream delivers it after
/// the frame it was emitted in.
Future<void> _settleStatus(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  group('title bar controls', () {
    for (final (name, theme) in [
      ('dark', AppTheme.dark),
      ('light', AppTheme.light),
    ]) {
      testWidgets('$name: 46 × 48 each, 8 px after the last control, '
          'Fermer in the corner', (tester) async {
        _useFrame(tester);
        await tester.pumpWidget(
          _shell(chrome: FakeWindowChrome(), theme: theme),
        );
        await tester.pumpAndSettle();

        final bar = tester.getRect(find.byKey(const Key('appTopBar')));
        final action = tester.getRect(find.byKey(const Key('action')));
        final minimize = tester.getRect(find.byKey(_minimize));
        final maximize = tester.getRect(find.byKey(_maximize));
        final close = tester.getRect(find.byKey(_close));

        for (final rect in [minimize, maximize, close]) {
          expect(rect.size, const Size(46, 48));
          expect(rect.top, bar.top);
        }
        expect(minimize.left - action.right, AppSpacing.sm);
        expect(maximize.left, minimize.right);
        expect(close.left, maximize.right);
        expect(close.right, bar.right);

        final colors = theme.extension<AppColors>()!;
        expect(_icon(tester, _close).color, colors.textSecondary);
        expect(_icon(tester, _close).size, AppSizes.icon);
        expect(_ground(tester, _close), Colors.transparent);
      });
    }

    testWidgets('each control acts on the window', (tester) async {
      _useFrame(tester);
      final chrome = FakeWindowChrome();
      await tester.pumpWidget(_shell(chrome: chrome));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_minimize));
      await tester.tap(find.byKey(_maximize));
      await tester.tap(find.byKey(_close));
      expect(chrome.calls, ['minimize', 'toggleMaximize', 'close']);
    });

    testWidgets('a maximized window offers « Restaurer »', (tester) async {
      _useFrame(tester);
      final chrome = FakeWindowChrome();
      await tester.pumpWidget(_shell(chrome: chrome));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Agrandir'), findsOneWidget);

      chrome.emit(const WindowStatus(maximized: true));
      await _settleStatus(tester);
      expect(find.byTooltip('Restaurer'), findsOneWidget);
      expect(find.byTooltip('Agrandir'), findsNothing);
    });

    testWidgets('tooltips and accessible labels, in French and English', (
      tester,
    ) async {
      _useFrame(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_shell(chrome: FakeWindowChrome()));
      await tester.pumpAndSettle();
      for (final label in ['Réduire', 'Agrandir', 'Fermer']) {
        expect(find.byTooltip(label), findsOneWidget);
      }
      expect(
        tester.getSemantics(find.byKey(_close)),
        matchesSemantics(label: 'Fermer', isButton: true, hasTapAction: true),
      );

      await tester.pumpWidget(
        _shell(chrome: FakeWindowChrome(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      for (final label in ['Minimize', 'Maximize', 'Close']) {
        expect(find.byTooltip(label), findsOneWidget);
      }
      semantics.dispose();
    });

    for (final (name, theme) in [
      ('dark', AppTheme.dark),
      ('light', AppTheme.light),
    ]) {
      testWidgets('$name: hover and pressed grounds', (tester) async {
        _useFrame(tester);
        final colors = theme.extension<AppColors>()!;
        await tester.pumpWidget(
          _shell(chrome: FakeWindowChrome(), theme: theme),
        );
        await tester.pumpAndSettle();

        final mouse = await _mouse(tester);
        await _hover(tester, mouse, _maximize);
        expect(_ground(tester, _maximize), colors.hover);
        expect(_icon(tester, _maximize).color, colors.text);

        await mouse.down(tester.getCenter(find.byKey(_maximize)));
        await tester.pump();
        expect(_ground(tester, _maximize), colors.lineStrong);
        await mouse.cancel();
        await tester.pump();

        await _hover(tester, mouse, _close);
        expect(_ground(tester, _close), colors.negative);
        expect(_icon(tester, _close).color, colors.bg);

        await mouse.down(tester.getCenter(find.byKey(_close)));
        await tester.pump();
        expect(
          _ground(tester, _close),
          Color.alphaBlend(
            colors.negative.withValues(alpha: 0.85),
            colors.text,
          ),
        );
        await mouse.cancel();
        await tester.pump();
      });
    }

    testWidgets(
      'inactive window: title and icons dim, hover keeps its colour',
      (tester) async {
        _useFrame(tester);
        final colors = AppTheme.dark.extension<AppColors>()!;
        final chrome = FakeWindowChrome();
        await tester.pumpWidget(_shell(chrome: chrome));
        await tester.pumpAndSettle();

        chrome.emit(const WindowStatus(focused: false));
        await _settleStatus(tester);
        for (final key in [_minimize, _maximize, _close]) {
          expect(_icon(tester, key).color, colors.textTertiary);
        }
        final title = tester.widget<Text>(
          find.byKey(const Key('titleBarTitle')),
        );
        expect(title.style?.color, colors.textTertiary);

        final mouse = await _mouse(tester);
        await _hover(tester, mouse, _minimize);
        expect(_ground(tester, _minimize), colors.hover);
        expect(_icon(tester, _minimize).color, colors.text);

        chrome.emit(const WindowStatus());
        await _settleStatus(tester);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('titleBarTitle')))
              .style
              ?.color,
          colors.text,
        );
      },
    );
  });

  group('drag area', () {
    testWidgets('the empty stretch of the title bar moves the window and '
        'double-click maximizes', (tester) async {
      _useFrame(tester);
      final chrome = FakeWindowChrome();
      await tester.pumpWidget(_shell(chrome: chrome));
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byKey(const Key('appTopBar')));
      final empty = Offset(bar.center.dx, bar.center.dy);
      await tester.dragFrom(empty, const Offset(80, 20));
      expect(chrome.calls, ['drag']);

      chrome.calls.clear();
      await tester.tapAt(empty);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(empty);
      await tester.pumpAndSettle();
      expect(chrome.calls, ['toggleMaximize']);
    });

    testWidgets('the title and the controls do not drag', (tester) async {
      _useFrame(tester);
      final chrome = FakeWindowChrome();
      await tester.pumpWidget(_shell(chrome: chrome));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('titleBarTitle')),
        const Offset(80, 20),
      );
      await tester.drag(find.byKey(_minimize), const Offset(-80, 20));
      expect(chrome.calls, isNot(contains('drag')));
    });

    testWidgets('the sidebar brand row moves the window', (tester) async {
      _useFrame(tester);
      final chrome = FakeWindowChrome();
      await tester.pumpWidget(_shell(chrome: chrome));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(BrandLockup), const Offset(80, 20));
      await tester.pumpAndSettle();
      expect(chrome.calls, ['drag']);
    });
  });

  group('macOS', () {
    testWidgets('the system draws the buttons; the lockup starts 14 px after '
        'them', (tester) async {
      _useFrame(tester);
      await tester.pumpWidget(
        _shell(chrome: FakeWindowChrome(), systemWindowButtons: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WindowControls), findsNothing);
      final brandRow = tester.getRect(
        find.byKey(const Key('brandRowDragArea')),
      );
      expect(brandRow.top, 0);
      expect(brandRow.height, AppSizes.titleBar);
      expect(
        tester.getRect(find.byType(BrandLockup)).left,
        AppSizes.macWindowButtonsInset +
            AppSizes.macWindowButtons +
            AppSizes.macBrandAfterButtons,
      );
    });
  });

  group('screens without a title bar', () {
    Widget authLike() => const Scaffold(
      body: ChromelessWindowFrame(child: Center(child: Text('form'))),
    );

    testWidgets('Windows and Linux: the controls float top right and the top '
        'band drags', (tester) async {
      _useFrame(tester);
      final chrome = FakeWindowChrome();
      await tester.pumpWidget(_app(chrome: chrome, home: authLike()));
      await tester.pumpAndSettle();

      final close = tester.getRect(find.byKey(_close));
      expect(close.topRight, const Offset(1440, 0));
      final band = tester.getRect(find.byKey(const Key('windowDragBand')));
      expect(band, const Rect.fromLTRB(0, 0, 1440 - 3 * 46.0, 48));

      await tester.dragFrom(const Offset(400, 24), const Offset(80, 20));
      await tester.pumpAndSettle();
      expect(chrome.calls, ['drag']);
      chrome.calls.clear();
      await tester.dragFrom(const Offset(400, 100), const Offset(80, 20));
      expect(chrome.calls, isEmpty);
    });

    testWidgets('macOS: no controls; the band leaves the system buttons', (
      tester,
    ) async {
      _useFrame(tester);
      await tester.pumpWidget(
        _app(
          chrome: FakeWindowChrome(),
          home: authLike(),
          systemWindowButtons: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WindowControls), findsNothing);
      final band = tester.getRect(find.byKey(const Key('windowDragBand')));
      expect(band, const Rect.fromLTRB(84, 0, 1440, 48));
    });
  });
}
