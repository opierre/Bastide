import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'inline_banner.dart';
import 'labeled_field.dart';
import 'state_views.dart';
import 'status_text.dart';

/// The body of a modal while it loads (`00` §7 « Modal », States): its
/// silhouette in `hover` blocks pulsing together, never a spinner. The
/// default draws the mockup's generic body (two lines of text, a row of two
/// fields, four list rows); a modal with another layout passes its own
/// [children], built from [SkeletonBlock]s.
class ModalLoadingBody extends StatelessWidget {
  const ModalLoadingBody({super.key, this.children});

  final List<Widget>? children;

  static const _textLine = AppSpacing.smPlus;
  static const _listRow = AppSpacing.lg - AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final blocks =
        children ??
        [
          const FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 0.8,
            child: SkeletonBlock(height: _textLine),
          ),
          const FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 0.55,
            child: SkeletonBlock(height: _textLine),
          ),
          const Row(
            children: [
              Expanded(child: SkeletonBlock(height: AppSizes.formField)),
              SizedBox(width: AppModalSizes.columnGutter),
              Expanded(child: SkeletonBlock(height: AppSizes.formField)),
            ],
          ),
          for (var i = 0; i < 4; i++) const SkeletonBlock(height: _listRow),
        ];
    return ExcludeSemantics(
      child: SkeletonPulse(
        key: const Key('modalLoadingBody'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, block) in blocks.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.smPlus),
              block,
            ],
          ],
        ),
      ),
    );
  }
}

/// A body that could not load (`00` §7 « Modal », States): a banner with a
/// `warning` icon saying what failed, and a secondary « Réessayer ».
class ModalLoadError extends StatelessWidget {
  const ModalLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => InlineBanner(
    key: const Key('modalLoadError'),
    message: message,
    tone: BannerTone.warning,
    actions: [
      AppButton(
        key: const Key('modalLoadErrorRetry'),
        label: AppLocalizations.of(context)!.modalRetry,
        onPressed: onRetry,
      ),
    ],
  );
}

/// An action that runs without closing the modal (« Exporter d’abord »).
/// Once it has succeeded ([done]), the button gives way to status text in
/// `positive` with `check` naming the result, until the modal closes. The
/// text is announced to screen readers, stands in for the toast the action
/// shows elsewhere, and focus moves back to the modal's initial focus
/// (`00` §7 « Modal », States).
class ModalInPlaceAction extends StatefulWidget {
  const ModalInPlaceAction({
    super.key,
    required this.action,
    required this.done,
    required this.doneLabel,
  });

  /// The button, shown until [done].
  final Widget action;
  final bool done;

  /// Names the result: « Sauvegarde enregistrée ».
  final String doneLabel;

  @override
  State<ModalInPlaceAction> createState() => _ModalInPlaceActionState();
}

class _ModalInPlaceActionState extends State<ModalInPlaceAction> {
  @override
  void didUpdateWidget(ModalInPlaceAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done) {
      final direction = Directionality.of(context);
      final view = View.of(context);
      SemanticsService.sendAnnouncement(view, widget.doneLabel, direction);
      // The button that held focus is gone.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppModal.focusInitial(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.done) return widget.action;
    return SizedBox(
      height: AppSizes.button,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: Semantics(
          liveRegion: true,
          child: StatusText(
            key: const Key('modalInPlaceDone'),
            label: widget.doneLabel,
            tone: StatusTone.positive,
          ),
        ),
      ),
    );
  }
}

/// A row of a list inside a modal body (`00` §7 « Modal », Body; §4): 36 px,
/// 48 px with two lines, padding 0 8, no hairline. A selectable row
/// ([onTap]) takes radius 4 and the `hover` ground under the pointer; the
/// selected one the `accentSoft` ground.
class ModalListRow extends StatefulWidget {
  const ModalListRow({
    super.key,
    required this.child,
    this.twoLines = false,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final bool twoLines;
  final VoidCallback? onTap;
  final bool selected;

  @override
  State<ModalListRow> createState() => _ModalListRowState();
}

class _ModalListRowState extends State<ModalListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectable = widget.onTap != null;
    final ground = widget.selected
        ? colors.accentSoft
        : selectable && _hovered
        ? colors.hover
        : null;
    final row = Container(
      height: widget.twoLines ? AppSizes.tableRowTwoLines : AppSizes.tableRow,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: ground,
        borderRadius: selectable || widget.selected
            ? BorderRadius.circular(AppRadii.item)
            : null,
      ),
      child: widget.child,
    );
    if (!selectable) return row;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }
}

/// A list of [ModalListRow]s, 2 px apart so two hover grounds never touch.
class ModalList extends StatelessWidget {
  const ModalList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, row) in children.indexed) ...[
        if (i > 0) const SizedBox(height: AppSpacing.xxs),
        row,
      ],
    ],
  );
}

/// One field of a [ModalFieldRow]: its label, its control, and an optional
/// helper or error under it.
@immutable
class ModalFieldCell {
  const ModalFieldCell({
    required this.label,
    required this.input,
    this.helper,
    this.errorText,
    this.trailing,
  });

  final String label;
  final Widget input;

  /// A reading set right of the label, as [LabeledField.trailing].
  final Widget? trailing;
  final String? helper;

  /// Takes precedence over [helper], as in [LabeledField].
  final String? errorText;
}

/// Two fields side by side, 16 px apart, aligned by their input (`00` §7
/// « Modal », Body): a label on two lines moves both inputs down together,
/// and a helper under one does not push its neighbour.
///
/// A [Table] rather than two columns: its rows are as tall as their tallest
/// cell, which is the CSS subgrid of the mockup.
class ModalFieldRow extends StatelessWidget {
  const ModalFieldRow({super.key, required this.start, required this.end});

  final ModalFieldCell start;
  final ModalFieldCell end;

  static const _labelGap = 5.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);

    Widget label(ModalFieldCell cell) => Padding(
      padding: const EdgeInsets.only(bottom: _labelGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(cell.label, style: labelStyle)),
          ?cell.trailing,
        ],
      ),
    );

    Widget below(ModalFieldCell cell) => switch (cell) {
      ModalFieldCell(:final errorText?) => FieldHelper(
        text: errorText,
        isError: true,
      ),
      ModalFieldCell(:final helper?) => FieldHelper(text: helper),
      _ => const SizedBox.shrink(),
    };

    const gutter = SizedBox(width: AppModalSizes.columnGutter);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FixedColumnWidth(AppModalSizes.columnGutter),
        2: FlexColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.bottom,
              child: label(start),
            ),
            gutter,
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.bottom,
              child: label(end),
            ),
          ],
        ),
        TableRow(children: [start.input, gutter, end.input]),
        TableRow(children: [below(start), gutter, below(end)]),
      ],
    );
  }
}
