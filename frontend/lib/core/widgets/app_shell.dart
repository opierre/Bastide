import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/sidebar_controller.dart';
import '../session/current_user_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'brand_mark.dart';
import 'frame_texture.dart';
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

/// Right-aligned controls a panel contributes to the top bar — a month
/// selector, a search pill, a primary action.
///
/// The shell resolves these from the current route rather than letting a screen
/// push into the bar during build: the top bar sits *above* the content in the
/// tree, so a child cannot fill a parent's slot in the same frame. Each panel's
/// controls are their own widget and watch whatever providers they need.
typedef TopBarActionsBuilder = List<Widget> Function(BuildContext context);

/// The fixed sidebar / top bar shell. Position and behaviour of the chrome are
/// identical on every panel — feature screens render only into [child] and
/// reach the bar through [actionsBuilder]. See `docs/design/00` §Layout invariant.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.currentPath,
    required this.onNavigate,
    required this.child,
    this.actionsBuilder,
  });

  final String currentPath;
  final ValueChanged<String> onNavigate;
  final Widget child;

  /// Contextual controls for the current panel, placed left of the user pill.
  final TopBarActionsBuilder? actionsBuilder;

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
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          label: l10n.navAccounts,
          subtitle: l10n.navAccountsSubtitle,
        ),
        NavDestinationSpec(
          path: '/transactions',
          icon: Icons.swap_vert_outlined,
          selectedIcon: Icons.swap_vert_rounded,
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
          icon: Icons.download_outlined,
          selectedIcon: Icons.download_rounded,
          label: l10n.navImports,
          subtitle: l10n.navImportsSubtitle,
        ),
        NavDestinationSpec(
          path: '/categories',
          icon: Icons.sell_outlined,
          selectedIcon: Icons.sell_rounded,
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
          icon: Icons.tune_outlined,
          selectedIcon: Icons.tune_rounded,
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
      body: FrameTexture(
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
                    actions: actionsBuilder?.call(context) ?? const [],
                  ),
                  Expanded(
                    child: ColoredBox(color: AppColors.surfaceBase, child: child),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collapsed = ref.watch(sidebarCollapsedProvider);

    // The last section (Settings) is pinned to the bottom so the primary
    // destinations keep the same vertical position as the app grows.
    final primarySections = sections.take(sections.length - 1);
    final pinnedSection = sections.last;

    return Container(
      width: collapsed ? AppChrome.sidebarCollapsedWidth : AppChrome.sidebarWidth,
      color: AppColors.surfaceSunken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          _SidebarHeader(collapsed: collapsed),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in primarySections)
                    ..._sectionChildren(context, section, collapsed),
                ],
              ),
            ),
          ),
          const Divider(
            color: AppColors.borderSubtle,
            indent: AppSpacing.sidebarGutter,
            endIndent: AppSpacing.sidebarGutter,
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._sectionChildren(context, pinnedSection, collapsed),
          _PrivacyBadge(collapsed: collapsed, label: l10n.sidebarPrivacyBadge),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  List<Widget> _sectionChildren(
    BuildContext context,
    NavSectionSpec section,
    bool collapsed,
  ) => [
    // The collapsed rail drops section labels rather than truncating them —
    // there is no width at which "Vue d'ensemble" reads as anything useful.
    if (section.label != null && !collapsed)
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sidebarGutter + AppSpacing.navInset,
          AppSpacing.sm,
          AppSpacing.sidebarGutter,
          AppSpacing.sm,
        ),
        child: Text(section.label!.toUpperCase(), style: AppTextStyles.sectionLabel),
      ),
    for (final destination in section.destinations)
      _NavItem(
        destination: destination,
        selected: destination.path == currentPath,
        collapsed: collapsed,
        onTap: () => onNavigate(destination.path),
      ),
    const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
  ];
}

class _SidebarHeader extends ConsumerWidget {
  const _SidebarHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final toggle = Tooltip(
      message: collapsed ? l10n.sidebarExpand : l10n.sidebarCollapse,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('sidebarToggleButton'),
          onTap: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: SizedBox(
            width: 26,
            height: 26,
            child: Icon(
              collapsed
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
              size: 16,
              color: AppColors.textDisabled,
            ),
          ),
        ),
      ),
    );

    if (collapsed) {
      return Column(
        children: [
          const BrandMark(size: 30),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          toggle,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sidebarGutter),
      child: Row(
        children: [const Expanded(child: BrandLockup.sidebar()), toggle],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final NavDestinationSpec destination;
  final bool selected;
  final bool collapsed;
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
        ? AppColors.iris
        : (_hovered ? AppColors.textPrimary : AppColors.textSecondary);

    final icon = Icon(
      selected ? widget.destination.selectedIcon : widget.destination.icon,
      size: AppChrome.navIconSize,
      color: foreground,
    );

    // Hover and selection are instant fills — the spec allows no transition on
    // chrome, and an animated pill pulls the eye to the nav rather than to the
    // panel that just changed.
    final pill = Container(
      height: AppChrome.navItemHeight,
      padding: widget.collapsed
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: AppSpacing.navInset),
      alignment: widget.collapsed ? Alignment.center : null,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.irisSoft
            : (_hovered ? AppColors.sidebarHover : Colors.transparent),
        borderRadius: BorderRadius.circular(AppRadii.navPill),
      ),
      child: widget.collapsed
          ? icon
          : Row(
              children: [
                icon,
                const SizedBox(width: AppSpacing.navGap),
                Expanded(
                  child: Text(
                    widget.destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          // Flush-left accent rail: reads as "you are here" even at a glance
          // across the whole sidebar height, and survives the collapse.
          SizedBox(
            width: AppChrome.navRailWidth,
            height: AppChrome.navRailHeight,
            child: selected
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.iris,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(AppRadii.pill),
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sidebarGutter - AppChrome.navRailWidth,
                right: AppSpacing.sidebarGutter,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onHover: (hovered) => setState(() => _hovered = hovered),
                  borderRadius: BorderRadius.circular(AppRadii.navPill),
                  child: widget.collapsed
                      ? Tooltip(message: widget.destination.label, child: pill)
                      : pill,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The always-visible reassurance at the sidebar foot. It replaces the old
/// bottom bar: the promise is about where the data lives, so it belongs beside
/// the app's identity rather than in a status strip.
class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.collapsed, required this.label});

  final bool collapsed;
  final String label;

  @override
  Widget build(BuildContext context) {
    const lock = Icon(
      Icons.lock_outline_rounded,
      size: 10,
      color: AppColors.textDisabled,
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Tooltip(message: label, child: const Center(child: lock)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sidebarGutter + AppSpacing.navInset,
        AppSpacing.sm,
        AppSpacing.sidebarGutter,
        0,
      ),
      child: Row(
        children: [
          lock,
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(
            child: Text(
              label,
              key: const Key('sidebarPrivacyBadge'),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textDisabled),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: AppChrome.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.contentX),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
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
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Actions size naturally and the title takes what's left: making them
          // flexible too would have the two split the bar evenly, squeezing
          // fixed-width controls that have a designed size.
          for (final action in actions) ...[
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            action,
          ],
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          const _UserPill(),
        ],
      ),
    );
  }
}

class _UserPill extends ConsumerWidget {
  const _UserPill();

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
        height: AppChrome.userPillHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserMonogram(name: user.displayName, size: 32),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email,
                    style: AppTextStyles.helper.copyWith(color: AppColors.textSecondary),
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
