import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_checkbox.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/series_preview.dart';

/// One checkable charge of « Ajouter à « … » » and « Marquer comme
/// récurrent » (`proposal_v6` `m-subscriptions`, #293): the checkbox, the
/// date, the bank label in Geist Mono over an optional caption (the account),
/// and the signed amount. A selectable [ModalListRow]: 36 px, 48 px with the
/// caption, radius 4, the `hover` ground under the pointer, no hairline. A
/// tap anywhere on the row toggles it.
class ChargeRow extends StatelessWidget {
  const ChargeRow({
    super.key,
    required this.transaction,
    required this.date,
    required this.ticked,
    required this.onChanged,
    this.caption,
  });

  final PreviewTransaction transaction;
  final String date;
  final bool ticked;

  /// `null` disables the row.
  final VoidCallback? onChanged;

  /// The line under the label: the account the charge was booked on.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final styles = context.textStyles;
    final caption = this.caption;
    final onChanged = this.onChanged;

    return ModalListRow(
      twoLines: caption != null,
      onTap: onChanged,
      child: Row(
        children: [
          AppCheckbox(
            value: ticked,
            onChanged: onChanged == null ? null : (_) => onChanged(),
            semanticLabel: transaction.label,
          ),
          const SizedBox(width: AppSpacing.smPlus),
          SizedBox(
            width: AppSubscriptions.chargeDateColumn,
            child: Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.mono.copyWith(color: colors.text),
                ),
                if (caption != null)
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.helper,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.smPlus),
          AmountText(
            amountMinor: transaction.amountMinor,
            currency: transaction.currency,
            style: textTheme.bodyMedium!,
          ),
        ],
      ),
    );
  }
}

/// A link in a modal body (`00` §6 « Link », §7: a navigation is not a
/// footer action): `accent`, 12 px, underlined on hover, focusable, with an
/// optional 14 px icon before it. « Ajouter à une série existante… »,
/// « Voir la série « … » », « Afficher plus ». Sized to its label: a body
/// column sets it in a [RecurringModalLinkLine].
class RecurringModalLink extends StatefulWidget {
  const RecurringModalLink({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;

  /// `null` disables the link.
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  State<RecurringModalLink> createState() => _RecurringModalLinkState();
}

class _RecurringModalLinkState extends State<RecurringModalLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onTap = widget.onTap;
    final icon = widget.icon;

    return FocusableActionDetector(
      enabled: onTap != null,
      mouseCursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: onTap,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.item,
          child: Semantics(
            link: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppSizes.iconSmall, color: colors.accent),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.accent,
                      decoration: _hovered ? TextDecoration.underline : null,
                      decorationColor: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [RecurringModalLink] on the start edge of a stretched body column, so
/// only the link itself takes the pointer.
class RecurringModalLinkLine extends StatelessWidget {
  const RecurringModalLinkLine({super.key, required this.link});

  final RecurringModalLink link;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: AlignmentDirectional.centerStart, child: link);
}

/// The search field both pickers open on: a 32 px field (`00` §6) with a
/// 14 px `search` icon and a placeholder.
class PickerSearchField extends StatelessWidget {
  const PickerSearchField({
    super.key,
    required this.fieldKey,
    required this.hint,
    required this.onChanged,
  });

  final Key fieldKey;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      child: TextField(
        key: fieldKey,
        autofocus: true,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.sm + AppSpacing.xxs,
              end: AppSpacing.sm,
            ),
            child: Icon(LucideIcons300.search, size: AppSizes.iconSmall),
          ),
          prefixIconConstraints: const BoxConstraints(),
        ),
      ),
    );
  }
}

/// A picker's list while it loads: the rows' silhouette in `hover` blocks
/// (`00` §7 « Modal », States), never a spinner.
class PickerLoading extends StatelessWidget {
  const PickerLoading({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) => ModalLoadingBody(
    children: [
      for (var i = 0; i < rows; i++)
        const SkeletonBlock(height: AppSpacing.lg - AppSpacing.xs),
    ],
  );
}

/// What a picker says instead of a list: nothing to offer, or no match.
class PickerMessage extends StatelessWidget {
  const PickerMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}
