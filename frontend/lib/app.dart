import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/backend/backend_providers.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/startup/startup_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/text_scale_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'l10n/app_localizations.dart';

class BastideApp extends ConsumerWidget {
  const BastideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final backend = ref.watch(backendControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final textScale = ref.watch(textScaleProvider);

    // Everything behind the router calls the API, so none of it is built
    // until the backend answers — and all of it goes away if the backend dies.
    final unconfirmedMismatch =
        backend.value?.mismatchedAppVersion != null &&
        !ref.watch(versionWarningDismissedProvider);
    if (backend.isLoading ||
        backend.hasError ||
        !backend.hasValue ||
        unconfirmedMismatch) {
      return MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        // The startup screen is always dark, like the installer splash it
        // continues, whatever the signed-in user's preference.
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const StartupScreen(),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
      // The user's text size scales every text below the router, chrome
      // included; the startup screen above keeps the reference scale.
      builder: (context, child) => AppTextScaleScope(
        factor: textScale,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
