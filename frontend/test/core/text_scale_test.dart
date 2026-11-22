import 'package:bastide/core/navigation/sidebar_controller.dart';
import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/storage/ui_preferences.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/text_scale_provider.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_shell.dart';
import 'package:bastide/core/widgets/chart_style.dart';
import 'package:bastide/core/window/window_providers.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/domain/text_size_preference.dart';
import 'package:bastide/features/transactions/application/review_count_provider.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/desktop_surface.dart';
import '../support/fake_auth_controller.dart';
import '../support/fake_dashboard_controller.dart';
import '../support/fake_ui_preferences.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

/// Reads the scaler a widget below [AppTextScaleScope] sees.
class _Probe extends StatelessWidget {
  const _Probe(this.onScaler);

  final ValueChanged<TextScaler> onScaler;

  @override
  Widget build(BuildContext context) {
    onScaler(MediaQuery.textScalerOf(context));
    return const SizedBox.shrink();
  }
}

void main() {
  group('TextSizePreference.fromWire', () {
    test('reads each value and falls back to normal', () {
      expect(TextSizePreference.fromWire('normal'), TextSizePreference.normal);
      expect(TextSizePreference.fromWire('large'), TextSizePreference.large);
      expect(TextSizePreference.fromWire('xlarge'), TextSizePreference.xlarge);
      for (final wire in [null, '', 'small', 'LARGE']) {
        expect(TextSizePreference.fromWire(wire), TextSizePreference.normal);
      }
    });
  });

  group('textScaleProvider', () {
    test('is the reference scale before anyone signs in', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(FakeAuthController.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      expect(container.read(textScaleProvider), AppTextScale.normal);
    });

    test('follows the signed-in user', () async {
      for (final (preference, factor) in [
        (TextSizePreference.normal, AppTextScale.normal),
        (TextSizePreference.large, AppTextScale.large),
        (TextSizePreference.xlarge, AppTextScale.xlarge),
      ]) {
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(
                initialUser: _user.withTextSize(preference),
              ),
            ),
          ],
        );
        await container.read(authControllerProvider.future);

        expect(container.read(textScaleProvider), factor);
        container.dispose();
      }
    });
  });

  group('AppTextScaleScope', () {
    Future<TextScaler> scalerUnder(
      WidgetTester tester, {
      required double factor,
      TextScaler system = TextScaler.noScaling,
    }) async {
      late TextScaler seen;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: system),
          child: AppTextScaleScope(
            factor: factor,
            child: _Probe((s) => seen = s),
          ),
        ),
      );
      return seen;
    }

    testWidgets('scales every size of the type scale by the same factor', (
      tester,
    ) async {
      final scaler = await scalerUnder(tester, factor: AppTextScale.xlarge);

      for (final size in [11.0, 12.0, 13.0, 16.0, 28.0, 40.0]) {
        expect(scaler.scale(size), closeTo(size * AppTextScale.xlarge, 1e-9));
      }
    });

    testWidgets('leaves the reference scale untouched', (tester) async {
      final scaler = await scalerUnder(tester, factor: AppTextScale.normal);

      expect(scaler, TextScaler.noScaling);
    });

    testWidgets('composes with the system text scale', (tester) async {
      final scaler = await scalerUnder(
        tester,
        factor: AppTextScale.large,
        system: const TextScaler.linear(1.5),
      );

      expect(scaler.scale(10), closeTo(10 * 1.5 * AppTextScale.large, 1e-9));
    });
  });

  testWidgets('ChartPaints.painted bakes the text scale into a painted label', (
    tester,
  ) async {
    late TextStyle painted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) =>
            AppTextScaleScope(factor: AppTextScale.xlarge, child: child!),
        home: Builder(
          builder: (context) {
            painted = ChartPaints.painted(
              context,
              ChartPaints.labelStyle(context),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(painted.fontSize, closeTo(11 * AppTextScale.xlarge, 1e-9));
  });

  group('the fixed chrome at the largest text size', () {
    Widget shell({required Locale locale, required bool collapsed}) =>
        ProviderScope(
          overrides: [
            uiPreferencesStoreProvider.overrideWithValue(
              FakeUiPreferencesStore(),
            ),
            if (collapsed)
              sidebarCollapsedProvider.overrideWith(FakeCollapsedSidebar.new),
            currentUserProvider.overrideWithValue(
              _user.withTextSize(TextSizePreference.xlarge),
            ),
            reviewCountProvider.overrideWith((ref) async => 128),
            systemWindowButtonsProvider.overrideWithValue(false),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              locale: locale,
              theme: AppTheme.dark,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => AppTextScaleScope(
                factor: ref.watch(textScaleProvider),
                child: child!,
              ),
              home: AppShell(
                currentPath: '/transactions',
                onNavigate: (_) {},
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final collapsed in [false, true]) {
        testWidgets('keeps its sizes and does not overflow '
            '(${locale.languageCode}, '
            '${collapsed ? 'collapsed' : 'expanded'})', (tester) async {
          useDesktopSurface(tester);
          await tester.pumpWidget(shell(locale: locale, collapsed: collapsed));
          await tester.pumpAndSettle();

          expect(
            tester.getSize(find.byKey(const Key('appNavRail'))).width,
            collapsed ? AppSizes.sidebarCollapsed : AppSizes.sidebar,
          );
          expect(
            tester.getSize(find.byKey(const Key('appTopBar'))).height,
            AppSizes.titleBar,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
