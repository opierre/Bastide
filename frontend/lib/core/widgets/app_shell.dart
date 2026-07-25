import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../session/current_user_provider.dart';
import '../theme/tokens.dart';
import 'brand_mark.dart';
import 'monogram_avatar.dart';

class NavDestinationSpec {
  const NavDestinationSpec({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.subtitle,
  });

  final String path;
  final IconData icon;

  /// Filled counterpart of [icon], shown when the destination is active — the
  /// outline/filled swap carries the selection alongside color, so the active
  /// item isn't signalled by color alone.
  final IconData selectedIcon;
  final String label;

  /// One-line descriptor of the panel, shown under the title in the top bar.
  final String subtitle;
}

class NavSectionSpec {
  const NavSectionSpec({required this.label, required this.destinations});

  /// `null` renders an unlabelled group (used for the pinned Settings group).
  final String? label;
  final List<NavDestinationSpec> destinations;
}

/// The fixed sidebar / top bar / bottom bar shell. Position and behaviour of
/// the three bars are identical on every panel — feature screens render only
/// into [child]. See `PROJECT.md` §9 and the design-system skill.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.currentPath,
    required this.onNavigate,
    required this.child,
  });

  final String currentPath;
  final ValueChanged<String> onNavigate;
  final Widget child;

  static List<NavSectionSpec> sections(AppLocalizations l10n) => [
    NavSectionSpec(
      label: l10n.navSectionOverview,
      destinations: [
        NavDestinationSpec(
          path: '/dashboard',
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard_rounded,
          label: l10n.navDashboard,
          subtitle: l10n.navDashboardSubtitle,
        ),
        NavDestinationSpec(
          path: '/accounts',
          icon: Icons.account_balance_outlined,
          selectedIcon: Icons.account_balance_rounded,
          label: l10n.navAccounts,
          subtitle: l10n.navAccountsSubtitle,
        ),
        NavDestinationSpec(
          path: '/transactions',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: l10n.navTransactions,
          subtitle: l10n.navTransactionsSubtitle,
        ),
      ],
    ),
    NavSectionSpec(
      label: l10n.navSectionManage,
      destinations: [
        NavDestinationSpec(
          path: '/imports',
          icon: Icons.upload_file_outlined,
          selectedIcon: Icons.upload_file_rounded,
          label: l10n.navImports,
          subtitle: l10n.navImportsSubtitle,
        ),
        NavDestinationSpec(
          path: '/categories',
          icon: Icons.donut_small_outlined,
          selectedIcon: Icons.donut_small_rounded,
          label: l10n.navCategories,
          subtitle: l10n.navCategoriesSubtitle,
        ),
      ],
    ),
    NavSectionSpec(
      label: null,
      destinations: [
        NavDestinationSpec(
          path: '/settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: l10n.navSettings,
          subtitle: l10n.navSettingsSubtitle,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final navSections = sections(l10n);
    final active = navSections
        .expand((section) => section.destinations)
        .where((destination) => destination.path == currentPath)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.surfaceSunken,
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  key: const Key('appNavRail'),
                  sections: navSections,
                  currentPath: currentPath,
                  onNavigate: onNavigate,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        key: const Key('appTopBar'),
                        title: active?.label ?? '',
                        subtitle: active?.subtitle ?? '',
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: AppColors.surfaceBase,
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BottomBar(key: const Key('appBottomBar'), l10n: l10n),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    super.key,
    required this.sections,
    required this.currentPath,
    required this.onNavigate,
  });

  final List<NavSectionSpec> sections;
  final String currentPath;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    // The last section (Settings) is pinned to the bottom so the primary
    // destinations keep the same vertical position as the app grows.
    final primarySections = sections.take(sections.length - 1);
    final pinnedSection = sections.last;

    return Container(
      width: AppChrome.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: BrandLockup(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in primarySections)
                    ..._sectionChildren(context, section),
                ],
              ),
            ),
          ),
          const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
          const SizedBox(height: AppSpacing.sm),
          ..._sectionChildren(context, pinnedSection),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  List<Widget> _sectionChildren(BuildContext context, NavSectionSpec section) => [
    if (section.label != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(
          section.label!.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textDisabled),
        ),
      ),
    for (final destination in section.destinations)
      _NavItem(
        destination: destination,
        selected: destination.path == currentPath,
        onTap: () => onNavigate(destination.path),
      ),
    const SizedBox(height: AppSpacing.md),
  ];
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestinationSpec destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final foreground = selected
        ? AppColors.brandAccent
        : (_hovered ? AppColors.textPrimary : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          // Flush-left accent rail: reads as "you are here" even at a glance
          // across the whole sidebar height.
          AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            width: 3,
            height: selected ? 20 : 0,
            decoration: const BoxDecoration(
              color: AppColors.brandAccent,
              borderRadius: BorderRadius.horizontal(
                right: Radius.circular(AppRadii.pill),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md + AppSpacing.xs + 1,
                right: AppSpacing.md,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onHover: (hovered) => setState(() => _hovered = hovered),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandAccentSoft
                          : (_hovered ? AppColors.overlayWash : Colors.transparent),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? widget.destination.selectedIcon
                              : widget.destination.icon,
                          size: 19,
                          color: foreground,
                        ),
                        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                        Expanded(
                          child: Text(
                            widget.destination.label,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: foreground,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: AppChrome.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg + AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const _UserMenu(),
        ],
      ),
    );
  }
}

class _UserMenu extends ConsumerWidget {
  const _UserMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    return PopupMenuButton<void>(
      key: const Key('userMenuButton'),
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, AppSpacing.sm),
      onSelected: (_) => ref.read(authControllerProvider.notifier).logout(),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          key: const Key('userMenuLogoutItem'),
          value: null,
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.userMenuLogout),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MonogramAvatar(name: user.displayName, size: 32),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Container(
      height: AppChrome.bottomBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.positive,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(l10n.statusBarReady, style: style),
          const Spacer(),
          const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textDisabled),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(l10n.statusBarLocalData, style: style),
        ],
      ),
    );
  }
}
