import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/state_views.dart';

/// The geometry of a setting row (`docs/design/09-settings.md` §Setting row).
abstract final class SettingRowMetrics {
  /// Width of the name and description column.
  static const labelWidth = 300.0;

  /// Vertical padding of a row, under its top hairline.
  static const paddingY = 14.0;

  /// Space above a section title that is not the first of its section.
  static const groupTop = AppSpacing.lg + AppSpacing.xs;
}

/// A section title, 16/600, 12 px above its first row and 28 px below the
/// previous group. No card, no tint around the group it opens.
class SettingsGroupTitle extends StatelessWidget {
  const SettingsGroupTitle({
    super.key,
    required this.title,
    this.first = false,
  });

  final String title;

  /// The first title of a section sits flush with the body's top padding.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : SettingRowMetrics.groupTop,
        bottom: AppSpacing.smPlus,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// The only building block of Paramètres: a top hairline, the setting's name
/// over a description on the left, and its controls stacked on the right.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.name,
    required this.description,
    required this.children,
    this.enabled = true,
  });

  final String name;
  final String description;

  /// The controls, stacked 8 px apart and left-aligned.
  final List<Widget> children;

  /// A row whose setting does not apply right now (the engine rows while the
  /// AI is off): drawn at 45 % and out of reach, like a disabled control.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    Widget row = Container(
      padding: const EdgeInsets.symmetric(vertical: SettingRowMetrics.paddingY),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: SettingRowMetrics.labelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.labelLarge?.copyWith(color: colors.text),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (!enabled) {
      row = IgnorePointer(
        child: ExcludeFocus(child: Opacity(opacity: 0.45, child: row)),
      );
    }
    return row;
  }
}

/// A section's loading state: its own silhouette, a title and row blocks in
/// `hover`, pulsing together (`00` §7, States of a panel).
class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.smPlus),
            child: SkeletonBlock(height: AppSpacing.md, width: 120),
          ),
          for (var i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: SettingRowMetrics.paddingY,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: SettingRowMetrics.labelWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(height: AppSpacing.smPlus, width: 140),
                        SizedBox(height: AppSpacing.xsPlus),
                        SkeletonBlock(height: AppSpacing.smPlus),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.lg),
                  SkeletonBlock(height: AppSizes.button, width: 160),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A link inside a setting row (`00` §6, Link): `accent`, 12 px beside status
/// text or 13 px on its own, underlined on hover, focusable. No arrow glyph.
class SettingsLink extends StatefulWidget {
  const SettingsLink({
    super.key,
    required this.label,
    required this.onTap,
    this.small = true,
  });

  final String label;
  final VoidCallback onTap;

  /// 12 px when true, 13 px otherwise.
  final bool small;

  @override
  State<SettingsLink> createState() => _SettingsLinkState();
}

class _SettingsLinkState extends State<SettingsLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return FocusableActionDetector(
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
        onTap: widget.onTap,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.item,
          child: Semantics(
            link: true,
            child: Text(
              widget.label,
              maxLines: 1,
              style: (widget.small ? textTheme.bodySmall : textTheme.bodyMedium)
                  ?.copyWith(
                    color: colors.accent,
                    decoration: _hovered ? TextDecoration.underline : null,
                    decorationColor: colors.accent,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
