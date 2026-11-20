import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../l10n/app_localizations.dart';
import 'about_section.dart';
import 'data_section.dart';
import 'preferences_section.dart';
import 'profile_section.dart';

/// Which section the body is showing.
enum SettingsSection { profile, preferences, data, about }

/// Width of the section nav (`09-settings.md` §Layout).
const _navWidth = 200.0;

/// The body stops growing past this width, so a row's description and its
/// controls stay close on a wide window.
const _bodyMaxWidth = 900.0;

/// Paramètres (`docs/design/09-settings.md`): a flush panel with the section
/// nav on the left and the section body, grouped rows separated by hairlines,
/// scrolling on its own on the right.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const path = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Purely local UI state: which section is open is not worth a provider,
  // and nothing outside this screen needs to read it.
  SettingsSection _section = SettingsSection.preferences;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('screen-settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionNav(
          active: _section,
          onSelect: (section) => setState(() => _section = section),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('settingsBody'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
                child: switch (_section) {
                  SettingsSection.profile => const ProfileSection(),
                  SettingsSection.preferences => const PreferencesSection(),
                  SettingsSection.data => const DataSection(),
                  SettingsSection.about => const AboutSection(),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.active, required this.onSelect});

  final SettingsSection active;
  final ValueChanged<SettingsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (
        SettingsSection.profile,
        LucideIcons300.user,
        l10n.settingsSectionProfile,
      ),
      (
        SettingsSection.preferences,
        LucideIcons300.slidersHorizontal,
        l10n.settingsSectionPreferences,
      ),
      (SettingsSection.data, LucideIcons300.database, l10n.settingsSectionData),
      (SettingsSection.about, LucideIcons300.info, l10n.settingsSectionAbout),
    ];

    return Container(
      width: _navWidth,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: context.colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (section, icon, label) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: _SectionNavItem(
                key: Key('settingsSection-${section.name}'),
                icon: icon,
                label: label,
                selected: section == active,
                onTap: () => onSelect(section),
              ),
            ),
        ],
      ),
    );
  }
}

/// A nav item per `00` §5: 30 px, radius 6, icon 16 + 9 px gap + label
/// 13/400 `textSecondary`; hover and active on `hover`, active in `text` 500.
class _SectionNavItem extends StatefulWidget {
  const _SectionNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SectionNavItem> createState() => _SectionNavItemState();
}

class _SectionNavItemState extends State<_SectionNavItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final foreground = widget.selected ? colors.text : colors.textSecondary;

    return Semantics(
      button: true,
      selected: widget.selected,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
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
              height: AppSizes.navItem,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: widget.selected || _hovered
                    ? colors.hover
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: AppSizes.icon, color: foreground),
                  const SizedBox(width: AppSpacing.navIconGap),
                  Expanded(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (widget.selected
                                  ? textTheme.labelLarge
                                  : textTheme.bodyMedium)
                              ?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
