import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/app_info.dart';
import 'package:bastide/core/l10n/locale_provider.dart';
import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/app_slider.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/settings/application/about_info.dart';
import 'package:bastide/features/settings/application/settings_controller.dart';
import 'package:bastide/features/settings/presentation/settings_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/desktop_surface.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _user = AuthUser(
  id: 'u1',
  email: 'camille.dubois@example.com',
  displayName: 'Camille Dubois',
  locale: 'fr',
  currency: 'EUR',
);

/// An invented data folder, away from the default one as `--data-dir` would
/// put it: the row must show what the backend reports, not a derived path.
const _dataDir = '/srv/camille/bastide-data';

Map<String, dynamic> _settingsJson({int? income, int savingsGoal = 20}) => {
  'ai_enabled': false,
  'inference_base_url': 'http://127.0.0.1:11434/v1',
  'model_tag': null,
  'confidence_threshold': 0.8,
  'declared_monthly_income_minor': income,
  'savings_rate_goal_percent': savingsGoal,
};

/// Mounts the screen under the real [localeProvider] so switching the language
/// re-renders it exactly as it would in the app.
class _Harness extends ConsumerWidget {
  const _Harness({this.theme});

  final ThemeData? theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: ref.watch(localeProvider),
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SettingsScreen()),
    );
  }
}

late _MockApiClient _api;

Widget _wrap({
  Future<String> Function()? readVersion,
  ThemeData? theme,
  int? income,
  int savingsGoal = 20,
  bool dataLocationFails = false,
  List<String>? openedFolders,
}) {
  _api = _MockApiClient();
  when(() => _api.get('/settings')).thenAnswer(
    (_) async => _settingsJson(income: income, savingsGoal: savingsGoal),
  );
  when(
    () => _api.get('/settings/updates'),
  ).thenAnswer((_) async => {'enabled': false, 'current_version': '0.1.0'});
  when(() => _api.get('/settings/data-location')).thenAnswer(
    (_) async => dataLocationFails
        ? throw StateError('backend unreachable')
        : {'db_path': '$_dataDir/bastide.db', 'data_dir': _dataDir},
  );
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_user),
      apiClientProvider.overrideWithValue(_api),
      appVersionProvider.overrideWith(
        (ref) => (readVersion ?? () async => '0.1.0')(),
      ),
      operatingSystemProvider.overrideWithValue('linux'),
      openFolderProvider.overrideWithValue(
        (dir) async => openedFolders?.add(dir),
      ),
    ],
    child: _Harness(theme: theme),
  );
}

Future<void> _open(WidgetTester tester, SettingsSection section) async {
  await tester.tap(find.byKey(Key('settingsSection-${section.name}')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  testWidgets('opens on Préférences, grouped as Affichage then Argent', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    for (final section in SettingsSection.values) {
      expect(
        find.byKey(Key('settingsSection-${section.name}')),
        findsOneWidget,
      );
    }
    expect(find.text('Affichage'), findsOneWidget);
    expect(find.text('Argent'), findsOneWidget);
    for (final row in [
      'settingsThemeRow',
      'settingsLanguageRow',
      'settingsFormatsRow',
      'settingsSidebarRow',
      'settingsCurrencyRow',
      'settingsSavingsGoalRow',
      'settingsIncomeRow',
    ]) {
      expect(find.byKey(Key(row)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching the language applies immediately, including formats', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('14 mai 2026 · 14/05/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsLocaleEnglishOption')));
    await tester.pumpAndSettle();

    // The promise under the control is "applies immediately": no save step.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('May 14, 2026 · 5/14/2026'), findsOneWidget);
    expect(find.text('Display'), findsOneWidget);
  });

  testWidgets('the sample amount is negative, signed with U+2212', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final amount = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('settingsAmountPreview')),
        matching: find.byType(Text),
      ),
    );
    expect(amount.data, startsWith('−'));
    expect(amount.data, contains('234,56'));
  });

  testWidgets('the currency is a settled value: code, name and symbol', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('EUR, euro (€)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('settingsCurrencyField')),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
  });

  testWidgets('the savings-rate goal is a 0–50 % slider with its value', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(savingsGoal: 35));
    await tester.pumpAndSettle();

    expect(find.text('Objectif de taux d’épargne'), findsOneWidget);
    expect(
      find.text('Le repère affiché sur le tableau de bord.'),
      findsOneWidget,
    );
    final slider = tester.widget<AppSlider>(
      find.byKey(const Key('settingsSavingsGoalSlider')),
    );
    expect(slider.value, 35);
    expect(slider.min, 0);
    expect(slider.max, 50);
    expect(slider.divisions, 50);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('settingsSavingsGoalValue')))
          .data,
      NumberFormat.percentPattern('fr').format(0.35),
    );
  });

  testWidgets('dragging the goal saves it once, as a whole percent', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    when(
      () => _api.patch('/settings', body: any(named: 'body')),
    ).thenAnswer((_) async => _settingsJson(savingsGoal: 50));

    // Far past the end: the slider stops at its 50 % maximum.
    await tester.drag(
      find.byKey(const Key('settingsSavingsGoalSlider')),
      const Offset(600, 0),
    );
    await tester.pump(settingsPatchDebounce * 2);
    await tester.pumpAndSettle();

    verify(
      () => _api.patch('/settings', body: {'savings_rate_goal_percent': 50}),
    ).called(1);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('settingsSavingsGoalValue')))
          .data,
      NumberFormat.percentPattern('fr').format(0.5),
    );
  });

  testWidgets('the declared income is shown and saved on submit', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(income: 320000));
    await tester.pumpAndSettle();
    when(
      () => _api.patch('/settings', body: any(named: 'body')),
    ).thenAnswer((_) async => _settingsJson(income: 410050));

    final field = find.descendant(
      of: find.byKey(const Key('settingsIncomeField')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).controller.text, contains('200'));

    await tester.enterText(field, '4100,50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(
      () => _api.patch(
        '/settings',
        body: {'declared_monthly_income_minor': 410050},
      ),
    ).called(1);
  });

  testWidgets('an emptied income field clears the declaration', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(income: 320000));
    await tester.pumpAndSettle();
    when(
      () => _api.patch('/settings', body: any(named: 'body')),
    ).thenAnswer((_) async => _settingsJson());

    final field = find.descendant(
      of: find.byKey(const Key('settingsIncomeField')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(
      () => _api.patch(
        '/settings',
        body: {'declared_monthly_income_minor': null},
      ),
    ).called(1);
  });

  testWidgets('Données: IA locale, Sauvegarde, then Réinitialisation', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _open(tester, SettingsSection.data);

    final ai = tester.getTopLeft(find.text('IA locale')).dy;
    final backup = tester.getTopLeft(find.text('Sauvegarde')).dy;
    final reset = tester.getTopLeft(find.text('Réinitialisation')).dy;
    // The way out is offered above the way through.
    expect(ai, lessThan(backup));
    expect(backup, lessThan(reset));
    expect(find.byKey(const Key('settingsCurrencyField')), findsNothing);
    // The v1 copy is gone.
    expect(find.text('Zone de danger'), findsNothing);
    expect(find.textContaining('IRRÉVERSIBLE'), findsNothing);
  });

  testWidgets(
    'Profil: avatar, name, email, password, recovery code, sign-out',
    (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await _open(tester, SettingsSection.profile);

      expect(find.text('Sécurité'), findsOneWidget);
      expect(find.text('Session'), findsOneWidget);
      expect(find.byKey(const Key('settingsAvatarRow')), findsOneWidget);
      expect(find.text('Camille Dubois'), findsOneWidget);
      expect(find.text('camille.dubois@example.com'), findsOneWidget);
      expect(find.byKey(const Key('settingsPasswordButton')), findsOneWidget);
      expect(find.byKey(const Key('settingsRecoveryButton')), findsOneWidget);
      expect(find.byKey(const Key('settingsLogoutButton')), findsOneWidget);
      // Password above the recovery code, and neither shows a date.
      expect(
        tester.getTopLeft(find.byKey(const Key('settingsPasswordRow'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('settingsRecoveryRow'))).dy,
        ),
      );
      expect(find.textContaining('Modifié le'), findsNothing);
      expect(find.textContaining('Dernier code généré'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('À propos: header, privacy, data location, licence, credits', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _open(tester, SettingsSection.about);

    expect(
      tester.widget<Text>(find.byKey(const Key('settingsAppVersion'))).data,
      'Version 0.1.0 · Linux',
    );
    expect(find.textContaining('restent sur cet ordinateur'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const Key('settingsAboutDataPath')),
          )
          .data,
      '$_dataDir/bastide.db',
    );
    expect(find.text('GNU Affero General Public License v3.0'), findsOneWidget);
    // Lucide's ISC notice is named where a user looks for credits.
    expect(
      tester.widget<Text>(find.byKey(const Key('settingsAboutCredits'))).data,
      contains('Lucide'),
    );
    expect(find.byKey(const Key('settingsAboutAllLicenses')), findsOneWidget);
  });

  testWidgets('À propos opens the data folder the backend reports', (
    tester,
  ) async {
    useDesktopSurface(tester);
    final opened = <String>[];
    await tester.pumpWidget(_wrap(openedFolders: opened));
    await tester.pumpAndSettle();
    await _open(tester, SettingsSection.about);

    await tester.ensureVisible(find.byKey(const Key('settingsAboutDataOpen')));
    await tester.tap(find.byKey(const Key('settingsAboutDataOpen')));
    await tester.pump();

    expect(opened, [_dataDir]);
  });

  testWidgets(
    'À propos shows a placeholder and no open button when the location fails',
    (tester) async {
      useDesktopSurface(tester);
      final opened = <String>[];
      await tester.pumpWidget(
        _wrap(dataLocationFails: true, openedFolders: opened),
      );
      await tester.pumpAndSettle();
      await _open(tester, SettingsSection.about);

      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const Key('settingsAboutDataPath')),
            )
            .data,
        '—',
      );
      await tester.ensureVisible(
        find.byKey(const Key('settingsAboutDataOpen')),
      );
      await tester.tap(find.byKey(const Key('settingsAboutDataOpen')));
      await tester.pump();
      expect(opened, isEmpty);
    },
  );

  testWidgets(
    'À propos says the version is unavailable when it cannot be read',
    (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(readVersion: () async => throw StateError('no package info')),
      );
      await tester.pumpAndSettle();
      await _open(tester, SettingsSection.about);

      expect(find.text('Version Indisponible · Linux'), findsOneWidget);
    },
  );

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    for (final locale in const ['fr', 'en']) {
      testWidgets('every section renders in the $name theme, in $locale', (
        tester,
      ) async {
        useDesktopSurface(tester);
        await tester.pumpWidget(_wrap(theme: theme));
        await tester.pumpAndSettle();
        if (locale == 'en') {
          await tester.tap(
            find.byKey(const Key('settingsLocaleEnglishOption')),
          );
          await tester.pumpAndSettle();
        }
        for (final section in SettingsSection.values) {
          await _open(tester, section);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
