import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/imports/presentation/imports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../widgets/app_shell.dart';

/// Redirect-guard stub: currently always allows navigation. Replaced by real
/// session-state checks once the auth feature exists.
final isAuthenticatedProvider = Provider<bool>((ref) => true);

final appRouterProvider = Provider<GoRouter>((ref) {
  // Watched so the router rebuilds once real auth state lands.
  ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: DashboardScreen.path,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentPath: state.matchedLocation,
            onNavigate: (path) => context.go(path),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: DashboardScreen.path,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AccountsScreen.path,
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: TransactionsScreen.path,
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: ImportsScreen.path,
            builder: (context, state) => const ImportsScreen(),
          ),
          GoRoute(
            path: CategoriesScreen.path,
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: SettingsScreen.path,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
