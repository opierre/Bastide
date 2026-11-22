import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/avatar_picture_controllers.dart';
import '../../features/transactions/application/review_count_provider.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/sidebar_controller.dart';
import '../session/current_user_provider.dart';
import '../theme/tokens.dart';
import '../window/window_providers.dart';
import 'app_popover.dart';
import 'brand_mark.dart';
import 'focus_ring.dart';
import 'tomettes.dart';
import 'user_avatar.dart';
import 'window_controls.dart';

class NavDestinationSpec {
  const NavDestinationSpec({
    required this.path,
    required this.icon,
    required this.label,
    this.showsReviewCount = false,
  });

  final String path;

  /// A Lucide glyph. Selection is carried by the item's ground and weight,
  /// never by a filled variant (`00` §5).
  final IconData icon;
  final String label;

  /// Whether the review-queue count sits at the item's right edge.
  final bool showsReviewCount;
}

class NavSectionSpec {
  const NavSectionSpec({required this.label, required this.destinations});

  final String label;
  final List<NavDestinationSpec> destinations;
}

/// Right-aligned controls a panel contributes to the title bar — a month
/// selector, a search field, a primary action.
///
/// The shell resolves these from the current route rather than letting a screen
/// push into the bar during build: the title bar sits *above* the content in
/// the tree, so a child cannot fill a parent's slot in the same frame. Each
/// panel's controls are their own widget and watch whatever providers they
/// need.
typedef TopBarActionsBuilder = List<Widget> Function(BuildContext context);

/// The title-bar title of a panel that names something more specific than its
/// section — an account's detail names the account, with a crumb back to the
/// list. Resolved from the route, like [TopBarActionsBuilder]; it returns a
/// [TitleBarTitle]. Panels without one show their section's label.
typedef TopBarTitleBuilder = Widget Function(BuildContext context);

/// Whether [path] is [destinationPath] or a page beneath it: an account's
/// detail (`/accounts/<id>`) keeps « Comptes » selected, since it is a view
/// *within* that section rather than a section of its own.
bool isWithinDestination(String path, String destinationPath) =>
    path == destinationPath || path.startsWith('$destinationPath/');

/// The fixed sidebar and title bar (`docs/design/00-design-system.md` §5).
///
/// Position and behaviour of the chrome are identical on every panel: feature
/// screens render only into [child] and reach the bar through
/// [actionsBuilder] and [titleBuilder]. `Ctrl+B` collapses and expands the
/// sidebar from anywhere in the window.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.currentPath,
    required this.onNavigate,
    required this.child,
    this.actionsBuilder,
    this.titleBuilder,
  });

  final String currentPath;
  final ValueChanged<String> onNavigate;
  final Widget child;

  /// Contextual controls for the current panel, at the title bar's right.
  final TopBarActionsBuilder? actionsBuilder;

  /// Replaces the section's label in the title bar.
  final TopBarTitleBuilder? titleBuilder;

  static List<NavSectionSpec> sections(AppLocalizations l10n) => [
    NavSectionSpec(
      label: l10n.navSectionOverview,
      destinations: [
        NavDestinationSpec(
          path: '/dashboard',
          icon: LucideIcons300.layoutDashboard,
          label: l10n.navDashboard,
        ),
        NavDestinationSpec(
          path: '/accounts',
          icon: LucideIcons300.wallet,
          label: l10n.navAccounts,
        ),
        NavDestinationSpec(
          path: '/transactions',
          icon: LucideIcons300.arrowLeftRight,
          label: l10n.navTransactions,
          showsReviewCount: true,
        ),
      ],
    ),
    NavSectionSpec(
      label: l10n.navSectionManage,
      destinations: [
        NavDestinationSpec(
          path: '/imports',
          icon: LucideIcons300.download,
          label: l10n.navImports,
        ),
        NavDestinationSpec(
          path: '/categories',
          icon: LucideIcons300.tags,
          label: l10n.navCategories,
        ),
        NavDestinationSpec(
          path: '/subscriptions',
          icon: LucideIcons300.repeat,
          label: l10n.navSubscriptions,
        ),
        NavDestinationSpec(
          path: '/goals',
          icon: LucideIcons300.flag,
          label: l10n.navGoals,
        ),
      ],
    ),
    NavSectionSpec(
      label: l10n.navSectionWealth,
      destinations: [
        NavDestinationSpec(
          path: '/mortgages',
          icon: LucideIcons300.house,
          label: l10n.navMortgages,
        ),
        NavDestinationSpec(
          path: '/investments',
          icon: LucideIcons300.chartLine,
          label: l10n.navPlacements,
        ),
        NavDestinationSpec(
          path: '/simulations',
          icon: LucideIcons300.calculator,
          label: l10n.navSimulator,
        ),
        NavDestinationSpec(
          path: '/networth',
          icon: LucideIcons300.chartPie,
          label: l10n.navNetworth,
        ),
      ],
    ),
  ];

  /// « Paramètres », below the sidebar's empty stretch so the primary items
  /// keep their vertical position as the app grows.
  static NavDestinationSpec settings(AppLocalizations l10n) =>
      NavDestinationSpec(
        path: '/settings',
        icon: LucideIcons300.settings,
        label: l10n.navSettings,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final navSections = sections(l10n);
    final active = [
      ...navSections.expand((section) => section.destinations),
      settings(l10n),
    ].where((d) => isWithinDestination(currentPath, d.path)).firstOrNull;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            ref.read(sidebarCollapsedProvider.notifier).toggle(),
      },
      // Holds the window's focus when no control has it, so the shortcut
      // works before anything was clicked.
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: context.colors.bg,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                key: const Key('appNavRail'),
                sections: navSections,
                settings: settings(l10n),
                currentPath: currentPath,
                onNavigate: onNavigate,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TitleBar(
                      key: const Key('appTopBar'),
                      title:
                          titleBuilder?.call(context) ??
                          TitleBarTitle(title: active?.label ?? ''),
                      actions: actionsBuilder?.call(context) ?? const [],
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    super.key,
    required this.sections,
    required this.settings,
    required this.currentPath,
    required this.onNavigate,
  });

  final List<NavSectionSpec> sections;
  final NavDestinationSpec settings;
  final String currentPath;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final systemButtons = ref.watch(systemWindowButtonsProvider);
    final colors = context.colors;

    Widget item(NavDestinationSpec destination) => _NavItem(
      key: Key('nav${destination.path}'),
      destination: destination,
      selected: isWithinDestination(currentPath, destination.path),
      collapsed: collapsed,
      onTap: () => onNavigate(destination.path),
    );

    return Container(
      width: collapsed ? AppSizes.sidebarCollapsed : AppSizes.sidebar,
      // On macOS the brand row is the window's top 48 px band, beside the
      // system's buttons, so it starts at the very top.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        systemButtons ? 0 : AppSpacing.smPlus,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.rail,
        border: Border(right: BorderSide(color: colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandRow(collapsed: collapsed, systemButtons: systemButtons),
          Expanded(
            // The groups scroll only when the window is shorter than the
            // stack; otherwise the empty stretch takes what is left.
            child: CustomScrollView(
              slivers: [
                SliverList.list(
                  children: [
                    for (final section in sections) ...[
                      if (collapsed)
                        // The group labels become a gap: no width reads
                        // « Vue d'ensemble » usefully at 56 px.
                        const SizedBox(height: AppSpacing.sm)
                      else
                        _GroupLabel(section.label),
                      for (final destination in section.destinations)
                        item(destination),
                    ],
                  ],
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Tomettes(fade: TomettesFade.vertical),
                ),
              ],
            ),
          ),
          item(settings),
          _SidebarFoot(collapsed: collapsed, onNavigate: onNavigate),
        ],
      ),
    );
  }
}

/// The brand row, which also moves the window (`00` §5).
///
/// On macOS it shares the window's top 48 px band with the system's three
/// buttons: the lockup starts 14 px after them, and the collapsed rail, which
/// the buttons overhang, hides the mark.
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.collapsed, required this.systemButtons});

  final bool collapsed;
  final bool systemButtons;

  /// Where the lockup starts on macOS, inside the sidebar's 8 px padding.
  static const _macLockupStart =
      AppSizes.macWindowButtonsInset +
      AppSizes.macWindowButtons +
      AppSizes.macBrandAfterButtons -
      AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    if (systemButtons) {
      return WindowDragArea(
        key: const Key('brandRowDragArea'),
        child: SizedBox(
          height: AppSizes.titleBar,
          child: collapsed
              ? null
              : const Padding(
                  padding: EdgeInsetsDirectional.only(start: _macLockupStart),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BrandLockup(),
                  ),
                ),
        ),
      );
    }
    return WindowDragArea(
      key: const Key('brandRowDragArea'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          collapsed ? 0 : AppSpacing.sm,
          AppSpacing.xs,
          collapsed ? 0 : AppSpacing.sm,
          AppSpacing.sidebarBrandBottom,
        ),
        child: collapsed
            ? const Center(child: BrandMark())
            : const Align(
                alignment: AlignmentDirectional.centerStart,
                child: BrandLockup(),
              ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sidebarLabelTop,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary),
      ),
    );
  }
}

/// A 30 px sidebar row: the shape of a nav item, shared by the destinations
/// and the user row. Hover and focus change at once (`00` §13); the focus
/// outline follows the row's radius.
class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.onTap,
    required this.selected,
    required this.collapsed,
    required this.tooltip,
    required this.builder,
    super.key,
    this.height = AppSizes.navItem,
  });

  final VoidCallback onTap;
  final bool selected;
  final bool collapsed;

  /// Shown on the collapsed sidebar, where the label is gone.
  final String tooltip;
  final double height;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highlighted = widget.selected || _hovered;

    Widget row = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.control,
          child: Container(
            height: widget.height,
            padding: widget.collapsed
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            alignment: widget.collapsed
                ? Alignment.center
                : AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              color: highlighted ? colors.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: widget.builder(context, _hovered),
          ),
        ),
      ),
    );

    row = Semantics(button: true, selected: widget.selected, child: row);
    return widget.collapsed
        ? Tooltip(message: widget.tooltip, child: row)
        : row;
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    super.key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final reviewCount = destination.showsReviewCount
        ? (ref.watch(reviewCountProvider).value ?? 0)
        : 0;

    return _SidebarRow(
      onTap: onTap,
      selected: selected,
      collapsed: collapsed,
      tooltip: destination.label,
      builder: (context, hovered) {
        final foreground = selected || hovered
            ? colors.text
            : colors.textSecondary;
        final icon = Icon(
          destination.icon,
          size: AppSizes.icon,
          color: foreground,
        );
        if (collapsed) return icon;
        return Row(
          children: [
            icon,
            const SizedBox(width: AppSpacing.navIconGap),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (selected ? textTheme.labelLarge : textTheme.bodyMedium)
                    ?.copyWith(color: foreground),
              ),
            ),
            // Hidden at zero: an empty queue is not news.
            if (reviewCount > 0)
              Text(
                '$reviewCount',
                key: const Key('sidebarReviewCount'),
                semanticsLabel: l10n.sidebarReviewCount(reviewCount),
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The sidebar foot, above a hairline: the user row that opens the user menu,
/// then the privacy line (`00` §5).
class _SidebarFoot extends StatelessWidget {
  const _SidebarFoot({required this.collapsed, required this.onNavigate});

  final bool collapsed;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserRow(collapsed: collapsed, onNavigate: onNavigate),
          _PrivacyLine(collapsed: collapsed),
        ],
      ),
    );
  }
}

enum _UserMenuAction { settings, logout }

class _UserRow extends ConsumerStatefulWidget {
  const _UserRow({required this.collapsed, required this.onNavigate});

  final bool collapsed;
  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends ConsumerState<_UserRow> {
  final _menu = MenuController();

  void _choose(_UserMenuAction action) {
    switch (action) {
      case _UserMenuAction.settings:
        widget.onNavigate('/settings');
      case _UserMenuAction.logout:
        // Signing out flips the session to null; the router's auth redirect
        // then takes the user back to the login screen.
        ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final colors = context.colors;
    final avatar = UserAvatar(
      name: user.displayName,
      avatar: user.avatar,
      image: ref.watch(avatarPictureProvider).value?.bytes,
      size: AppSizes.avatarSmall,
    );

    return MenuAnchor(
      controller: _menu,
      style: AppPopover.menuStyle(context),
      menuChildren: [
        AppMenuItem(
          key: const Key('userMenuSettingsItem'),
          label: l10n.navSettings,
          leading: const Icon(LucideIcons300.settings),
          onPressed: () => _choose(_UserMenuAction.settings),
        ),
        AppMenuItem(
          key: const Key('userMenuLogoutItem'),
          label: l10n.userMenuLogout,
          leading: const Icon(LucideIcons300.logOut),
          onPressed: () => _choose(_UserMenuAction.logout),
        ),
      ],
      child: _SidebarRow(
        key: const Key('userMenuButton'),
        onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
        selected: false,
        collapsed: widget.collapsed,
        tooltip: user.displayName,
        height: AppSizes.navItem + AppSpacing.xs,
        builder: (context, hovered) {
          if (widget.collapsed) return avatar;
          return Row(
            children: [
              avatar,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.text),
                ),
              ),
              Icon(
                LucideIcons300.chevronsUpDown,
                size: AppSizes.iconSmall,
                color: colors.textTertiary,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The always-visible promise about where the data lives. It replaced the v1
/// bottom bar and belongs beside the user, whose data it describes.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final lock = Icon(
      LucideIcons300.lock,
      size: AppSizes.iconSmall,
      color: colors.textTertiary,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 0 : AppSpacing.sm,
        vertical: AppSpacing.xsPlus,
      ),
      child: collapsed
          ? Tooltip(
              message: l10n.sidebarPrivacyBadge,
              child: Center(child: lock),
            )
          : Row(
              children: [
                lock,
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.sidebarPrivacyBadge,
                    key: const Key('sidebarPrivacyBadge'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                  ),
                ),
              ],
            ),
    );
  }
}

/// A link back to the parent of the page a title names: « Comptes / ».
class TitleBarCrumb {
  const TitleBarCrumb({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

/// The title bar's title: an optional parent [crumb], then the title at
/// 14/600 (`00` §5). No subtitle and no descriptor, ever. The title takes
/// `textTertiary` while the window is inactive.
class TitleBarTitle extends ConsumerWidget {
  const TitleBarTitle({super.key, required this.title, this.crumb});

  final String title;
  final TitleBarCrumb? crumb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final focused = ref.watch(windowStatusProvider.select((s) => s.focused));
    return Row(
      children: [
        if (crumb case final crumb?) ...[
          _CrumbLink(crumb: crumb),
          const SizedBox(width: AppSpacing.xsPlus),
        ],
        Flexible(
          child: Text(
            title,
            key: const Key('titleBarTitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: focused
                ? textTheme.titleMedium
                : textTheme.titleMedium?.copyWith(
                    color: context.colors.textTertiary,
                  ),
          ),
        ),
      ],
    );
  }
}

class _CrumbLink extends StatefulWidget {
  const _CrumbLink({required this.crumb});

  final TitleBarCrumb crumb;

  @override
  State<_CrumbLink> createState() => _CrumbLinkState();
}

class _CrumbLinkState extends State<_CrumbLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.textTertiary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.crumb.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.crumb.onTap,
            child: FocusRing(
              focused: _focused,
              radius: AppRadii.item,
              child: Semantics(
                link: true,
                child: Text(
                  widget.crumb.label,
                  key: const Key('titleBarCrumb'),
                  style: style?.copyWith(
                    decoration: _hovered ? TextDecoration.underline : null,
                    decorationColor: colors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xsPlus),
        ExcludeSemantics(child: Text('/', style: style)),
      ],
    );
  }
}

/// The 48 px title bar (`00` §5): title, contextual controls and, on
/// Windows and Linux, the window controls against the right edge, with no
/// right padding so Fermer meets the window corner. Its empty stretch moves
/// the window; the title, the crumb and the controls sit above that area and
/// take the pointer themselves.
class _TitleBar extends ConsumerWidget {
  const _TitleBar({super.key, required this.title, required this.actions});

  final Widget title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemButtons = ref.watch(systemWindowButtonsProvider);
    return Container(
      height: AppSizes.titleBar,
      color: context.colors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The hairline is drawn first so the window controls, 48 px tall,
          // cover it as they meet the corner.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: context.colors.line),
          ),
          const Positioned.fill(
            child: WindowDragArea(key: Key('titleBarDragArea')),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: systemButtons ? AppSpacing.lg : 0,
            ),
            child: Row(
              children: [
                // The controls keep their designed size and the title takes
                // what is left, ellipsizing first.
                Expanded(child: title),
                for (final (index, action) in actions.indexed) ...[
                  SizedBox(
                    width: index == 0 ? AppSpacing.smPlus : AppSpacing.sm,
                  ),
                  action,
                ],
                if (!systemButtons) ...[
                  if (actions.isNotEmpty) const SizedBox(width: AppSpacing.sm),
                  const WindowControls(key: Key('windowControls')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
