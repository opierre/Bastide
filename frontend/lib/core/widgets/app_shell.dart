import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

class NavDestinationSpec {
  const NavDestinationSpec({
    required this.path,
    required this.icon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final String label;
}

/// The fixed left nav / top bar / bottom bar shell. Position and behaviour of
/// the three bars are identical on every panel — feature screens render only
/// into [child]. See `PROJECT.md` §9 and the design-system skill.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentPath,
    required this.onNavigate,
    required this.child,
  });

  final String currentPath;
  final ValueChanged<String> onNavigate;
  final Widget child;

  List<NavDestinationSpec> _destinations(AppLocalizations l10n) => [
    NavDestinationSpec(
      path: '/dashboard',
      icon: Icons.dashboard_outlined,
      label: l10n.navDashboard,
    ),
    NavDestinationSpec(
      path: '/accounts',
      icon: Icons.account_balance_outlined,
      label: l10n.navAccounts,
    ),
    NavDestinationSpec(
      path: '/transactions',
      icon: Icons.receipt_long_outlined,
      label: l10n.navTransactions,
    ),
    NavDestinationSpec(
      path: '/imports',
      icon: Icons.file_upload_outlined,
      label: l10n.navImports,
    ),
    NavDestinationSpec(
      path: '/categories',
      icon: Icons.category_outlined,
      label: l10n.navCategories,
    ),
    NavDestinationSpec(
      path: '/settings',
      icon: Icons.settings_outlined,
      label: l10n.navSettings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = _destinations(l10n);
    final selectedIndex = destinations.indexWhere((d) => d.path == currentPath);

    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            key: const Key('appTopBar'),
            title: selectedIndex >= 0 ? destinations[selectedIndex].label : '',
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  key: const Key('appNavRail'),
                  extended: true,
                  minExtendedWidth: 220,
                  selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
                  onDestinationSelected: (index) =>
                      onNavigate(destinations[index].path),
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: child),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _BottomBar(key: const Key('appBottomBar'), status: l10n.statusBarReady),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.centerLeft,
      color: AppColors.surfaceRaised,
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.centerLeft,
      color: AppColors.surfaceRaised,
      child: Text(status, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
