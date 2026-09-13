import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/accounts/presentation/accounts_top_bar_actions.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/categories/presentation/categories_top_bar_actions.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/month_selector.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/imports/presentation/imports_screen.dart';
import '../../features/mortgages/presentation/mortgages_screen.dart';
import '../../features/networth/presentation/networth_screen.dart';
import '../../features/recurring/presentation/subscriptions_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/simulator/presentation/simulator_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../widgets/app_shell.dart';

/// Notifies go_router's `redirect` to re-run whenever auth state changes
/// (session restore resolving, login, logout) so a single router instance
/// can be reused instead of rebuilt on every state change.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

/// The contextual controls each panel contributes to the top bar.
///
/// Resolved from the route here rather than pushed up by the screen: the top
/// bar is built above the content region, so a child cannot fill a parent's
/// slot in the same frame. Each panel's controls are their own widget and watch
/// whatever providers they need, which keeps the shell ignorant of features.
TopBarActionsBuilder? _topBarActions(String path) => switch (path) {
  '/dashboard' => (context) => const [DashboardTopBarActions()],
  '/accounts' => (context) => const [AccountsTopBarActions()],
  '/transactions' => (context) => const [TransactionsTopBarActions()],
  '/categories' => (context) => const [CategoriesTopBarActions()],
  '/subscriptions' => (context) => const [SubscriptionsTopBarActions()],
  '/goals' => (context) => const [GoalsTopBarActions()],
  '/mortgages' => (context) => const [MortgagesTopBarActions()],
  '/simulations' => (context) => const [SimulatorTopBarActions()],
  '/networth' => (context) => const [NetworthTopBarActions()],
  _ => null,
};

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: LoginScreen.path,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      if (authState.isLoading) return null;

      final isAuthenticated = authState.value != null;
      final isAuthRoute =
          state.matchedLocation == LoginScreen.path ||
          state.matchedLocation == RegisterScreen.path;

      if (!isAuthenticated && !isAuthRoute) return LoginScreen.path;
      if (isAuthenticated && isAuthRoute) return DashboardScreen.path;
      return null;
    },
    routes: [
      GoRoute(
        path: LoginScreen.path,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RegisterScreen.path,
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentPath: state.matchedLocation,
            onNavigate: (path) => context.go(path),
            actionsBuilder: _topBarActions(state.matchedLocation),
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
            path: SubscriptionsScreen.path,
            builder: (context, state) => const SubscriptionsScreen(),
          ),
          GoRoute(
            path: GoalsScreen.path,
            builder: (context, state) => const GoalsScreen(),
          ),
          GoRoute(
            path: MortgagesScreen.path,
            builder: (context, state) => const MortgagesScreen(),
          ),
          GoRoute(
            path: SimulatorScreen.path,
            builder: (context, state) => const SimulatorScreen(),
          ),
          GoRoute(
            path: NetworthScreen.path,
            builder: (context, state) => const NetworthScreen(),
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
