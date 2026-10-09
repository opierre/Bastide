import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/backend/backend_providers.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/startup/startup_screen.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class BastideApp extends ConsumerWidget {
  const BastideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final backend = ref.watch(backendControllerProvider);

    // Everything behind the router calls the API, so none of it is built
    // until the backend answers — and all of it goes away if the backend dies.
    if (backend.isLoading || backend.hasError || !backend.hasValue) {
      return MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        theme: appDarkTheme,
        darkTheme: appDarkTheme,
        themeMode: ThemeMode.dark,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const StartupScreen(),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: appDarkTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
