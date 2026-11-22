import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'app_button.dart';
import 'inline_banner.dart';

/// What a modal is for. It decides where focus lands when the modal opens
/// and whether Escape and the scrim may close it (`00` §7 « Modal »,
/// Closing, Keyboard, Variants).
enum AppModalKind {
  /// A form: focus on its first field. Escape and the scrim act as the
  /// secondary action until the form holds unsaved input ([AppModal.dirty]).
  form,

  /// A reversible confirmation: focus on the primary action.
  confirmation,

  /// A destructive confirmation: focus on « Annuler », so Enter deletes
  /// nothing by mistake.
  destructive,

  /// Something shown once (a recovery code): focus on the body's first
  /// action, the copy one; Escape and the scrim do nothing.
  singleWayOut,

  /// A result to read: focus on its one « Fermer ».
  acknowledgement,

  /// A modal that edits a list in place: focus on the entry row's first
  /// field; its footer has a single « Fermer ».
  listEditor,
}

/// Shows a modal route for an [AppModal] (or the [LogoZoomDialog]): the
/// `scrim` behind it and the 120 ms ease-out fade of `00` §13, none with
/// the OS "reduce motion" setting.
///
/// The barrier itself never closes the route: the modal decides what a click
/// on the scrim does, since that depends on its kind and state.
Future<T?> showAppModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final duration = MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : AppMotion.overlay;
  // Focus returns to what opened the modal (`00` §7, Keyboard).
  final opener = FocusManager.instance.primaryFocus;
  final route = showDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: context.colors.scrim,
    animationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
      curve: Curves.easeOut,
    ),
    builder: builder,
  );
  return route.whenComplete(() {
    if (opener != null && opener.context != null && opener.canRequestFocus) {
      opener.requestFocus();
    }
  });
}

/// The modal of `docs/design/00-design-system.md` §7 « Modal »: `surface`,
/// radius 12, `shadow`, no border, centred on the `scrim`, at most the window
/// height minus 24 px above and below.
///
/// - Header: padding 24 24 14, the title 16/600 with its lines balanced, an
///   optional lead 13 `textSecondary` 4 px under it that never ends on a lone
///   word. No glyph before the title, no close button.
/// - Body: padding 0 24. Only the body scrolls; while it does, a `line`
///   hairline separates it from the header and the footer, 14 px from its
///   content. A modal without a body keeps its footer 24 px under the lead.
/// - Footer: padding 24; [actions] right-aligned, secondary then primary,
///   8 px apart, wrapping rather than overflowing; a tertiary ghost
///   [leadingAction] alone on the left.
///
/// The frame owns closing and focus: Escape and the scrim act as the
/// secondary action on a confirmation and an untouched form, ask
/// « Abandonner les modifications ? » once the form is [dirty], and do
/// nothing while [busy] or on a [AppModalKind.singleWayOut]. Focus stays
/// inside the modal and lands where [kind] says. A cancel button that has to
/// follow the same rules is an [AppModalCancel].
class AppModal extends StatefulWidget {
  const AppModal({
    super.key,
    required this.title,
    required this.width,
    required this.actions,
    this.child,
    this.subtitle,
    this.leadingAction,
    this.kind = AppModalKind.form,
    this.dirty = false,
    this.busy = false,
    this.saveError,
    this.onSubmit,
    this.onCancel,
  });

  /// The title; also the modal's accessible name.
  final String title;

  /// One of [AppModalSizes.widths], named by the panel spec. The modal never
  /// widens for a label.
  final double width;

  /// The lead under the title, 13 `textSecondary` when it is a [Text]
  /// without a colour of its own; also the modal's accessible description.
  final Widget? subtitle;

  /// The body. `null` for a confirmation, whose footer then sits 24 px under
  /// the lead.
  final Widget? child;

  /// Footer buttons, laid out right-aligned in order: secondary first,
  /// primary last.
  final List<Widget> actions;

  /// A tertiary ghost action set alone on the footer's left: « Supprimer »
  /// in an edit form, « Retour à l’aperçu » in a second step.
  final Widget? leadingAction;

  final AppModalKind kind;

  /// The form holds unsaved input: the scrim no longer closes it, and Escape
  /// or [AppModalCancel] ask before losing it.
  final bool dirty;

  /// A save is running: nothing closes, the body and every action but the
  /// last (the primary, which shows its own spinner) are disabled, and
  /// [onSubmit] is ignored.
  final bool busy;

  /// Why the last save failed: a banner with a `negative` icon at the top of
  /// the body. The input stays as it was.
  final String? saveError;

  /// What Enter does from a single-line field of the body: the primary
  /// action of a form.
  final VoidCallback? onSubmit;

  /// The secondary action that Escape, the scrim and [AppModalCancel] stand
  /// for. Defaults to closing the modal with no result.
  final VoidCallback? onCancel;

  /// Runs [AppModalCancel]'s action from inside a modal: asks before losing
  /// unsaved input, does nothing while a save runs.
  static void cancel(BuildContext context) => _scopeOf(context)?.cancel();

  /// Moves focus back to the modal's initial focus, after an in-place action
  /// has replaced the button that held it (`00` §7, States).
  static void focusInitial(BuildContext context) =>
      _scopeOf(context)?.focusInitial();

  static _AppModalState? _scopeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_AppModalScope>()?.state;

  @override
  State<AppModal> createState() => _AppModalState();
}

class _AppModalState extends State<AppModal> {
  final _scope = FocusScopeNode(debugLabel: 'AppModal');

  // Plain markers around the body and the footer: they never take focus
  // themselves, they only let the modal find the first or last control in
  // each part.
  final _body = FocusNode(
    debugLabel: 'AppModal body',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _footer = FocusNode(
    debugLabel: 'AppModal footer',
    canRequestFocus: false,
    skipTraversal: true,
  );

  final _scroll = ScrollController();
  bool _scrolls = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrolls();
      // A caller's own `autofocus` wins; the kind's rule applies otherwise.
      final focused = FocusManager.instance.primaryFocus;
      final inside =
          focused != null &&
          focused != _scope &&
          focused.ancestors.contains(_scope);
      if (!inside) focusInitial();
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    _body.dispose();
    _footer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _closable =>
      !widget.busy && widget.kind != AppModalKind.singleWayOut;

  void focusInitial() {
    final body = _body.traversalDescendants;
    final footer = _footer.traversalDescendants;
    final target = switch (widget.kind) {
      AppModalKind.form ||
      AppModalKind.listEditor ||
      AppModalKind.singleWayOut => body.firstOrNull ?? footer.lastOrNull,
      AppModalKind.destructive => footer.firstOrNull,
      AppModalKind.confirmation ||
      AppModalKind.acknowledgement => footer.lastOrNull,
    };
    if (target != null) {
      target.requestFocus();
    } else {
      _scope.requestFocus();
    }
  }

  void _dismiss() {
    if (widget.onCancel case final onCancel?) {
      onCancel();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Escape and [AppModalCancel].
  Future<void> cancel() async {
    if (!_closable || _asking) return;
    if (!widget.dirty) return _dismiss();
    _asking = true;
    final discard = await showAppModal<bool>(
      context: context,
      builder: (_) => _DiscardModal(form: widget.title),
    );
    _asking = false;
    if (discard == true && mounted) _dismiss();
  }

  void _onScrim() {
    // Unsaved input is never lost to a stray click.
    if (_closable && !widget.dirty) _dismiss();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final onSubmit = widget.onSubmit;
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>();
    if (onSubmit == null || field == null || field.maxLines != 1) {
      return KeyEventResult.ignored;
    }
    if (!widget.busy) onSubmit();
    return KeyEventResult.handled;
  }

  void _updateScrolls() {
    if (!mounted || !_scroll.hasClients) return;
    final scrolls = _scroll.position.maxScrollExtent > 0;
    if (scrolls != _scrolls) setState(() => _scrolls = scrolls);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      AppModalSizes.widths.contains(widget.width),
      'A modal takes one of the widths of `00` §7: ${AppModalSizes.widths}.',
    );
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final lead = widget.subtitle;
    final body = widget.child;
    final error = widget.saveError;
    final hasBody = body != null || error != null;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        AppModalSizes.padding,
        AppModalSizes.padding,
        AppModalSizes.padding,
        hasBody ? AppModalSizes.headerBottom : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModalTextWrap.balanced(
            child: Text(
              widget.title,
              key: const Key('appModalTitle'),
              style: textTheme.headlineSmall,
            ),
          ),
          if (lead != null) ...[
            const SizedBox(height: AppModalSizes.leadGap),
            DefaultTextStyle.merge(
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
              child: ModalTextWrap.pretty(child: lead),
            ),
          ],
        ],
      ),
    );

    Widget? content;
    if (hasBody) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            InlineBanner(
              key: const Key('appModalSaveError'),
              message: error,
              tone: BannerTone.error,
            ),
            if (body != null) const SizedBox(height: AppSpacing.fieldGap),
          ],
          ?body,
        ],
      );
      if (widget.busy) content = _Disabled(child: content);
    }

    final actions = [
      for (final (i, action) in widget.actions.indexed)
        widget.busy && i < widget.actions.length - 1
            ? _Disabled(child: action)
            : action,
    ];
    final leadingAction = widget.leadingAction;

    final footer = Focus(
      focusNode: _footer,
      child: Padding(
        padding: const EdgeInsets.all(AppModalSizes.padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadingAction != null) ...[
              widget.busy ? _Disabled(child: leadingAction) : leadingAction,
              const SizedBox(width: AppSpacing.sm),
            ],
            // A [Wrap], not a [Row]: French labels run 15–20 % past their
            // English counterparts. Identical to a row while the actions
            // fit, it drops to a second line instead of overflowing.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );

    Widget hairline(String key) =>
        Divider(key: Key(key), height: 1, thickness: 1, color: colors.line);

    final frame = Container(
      key: const Key('appModalFrame'),
      width: widget.width,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.modal),
        boxShadow: colors.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (content != null) ...[
            if (_scrolls) ...[
              hairline('appModalHeaderHairline'),
              const SizedBox(height: AppModalSizes.scrollEdge),
            ],
            Flexible(
              child: Focus(
                focusNode: _body,
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (_) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _updateScrolls(),
                    );
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppModalSizes.padding,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
            if (_scrolls) ...[
              const SizedBox(height: AppModalSizes.scrollEdge),
              hairline('appModalFooterHairline'),
            ],
          ],
          footer,
        ],
      ),
    );

    return _AppModalScope(
      state: this,
      child: Actions(
        actions: {
          // Always enabled, so Escape never falls through to the route's own
          // dismiss: the modal decides.
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              cancel();
              return null;
            },
          ),
        },
        child: FocusScope(
          node: _scope,
          onKeyEvent: _onKey,
          // The scrim is not announced: Escape is its keyboard twin.
          child: GestureDetector(
            key: const Key('appModalScrim'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _onScrim,
            child: Padding(
              padding: const EdgeInsets.all(AppModalSizes.windowInset),
              child: Center(
                // Taps on the frame are the frame's, never the scrim's.
                child: GestureDetector(
                  excludeFromSemantics: true,
                  onTap: () {},
                  child: Semantics(
                    key: const Key('appModalSemantics'),
                    container: true,
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: widget.title,
                    hint: _plainText(lead),
                    // The transparent [Material] that text fields and ink
                    // need above them, which [Dialog] used to provide.
                    child: Material(
                      type: MaterialType.transparency,
                      child: frame,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The text a lead reads out, when it is a [Text].
String? _plainText(Widget? widget) => switch (widget) {
  Text(:final data?) => data,
  Text(:final textSpan?) => textSpan.toPlainText(),
  _ => null,
};

class _AppModalScope extends InheritedWidget {
  const _AppModalScope({required this.state, required super.child});

  final _AppModalState state;

  @override
  bool updateShouldNotify(_AppModalScope oldWidget) => false;
}

/// Disabled as `00` §6 draws it: 45 % opacity, no pointer, out of the focus
/// order.
class _Disabled extends StatelessWidget {
  const _Disabled({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeFocus(child: Opacity(opacity: 0.45, child: child)),
  );
}

/// The modal's secondary action, « Annuler » unless [label] says otherwise
/// (« Plus tard » when Bastide proposed the task). It follows the frame's
/// closing rules: it asks before losing unsaved input and is disabled while
/// a save runs.
class AppModalCancel extends StatelessWidget {
  const AppModalCancel({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => AppButton(
    key: key == null ? const Key('appModalCancel') : null,
    label: label ?? AppLocalizations.of(context)!.modalCancel,
    onPressed: () => AppModal.cancel(context),
  );
}

/// « Fermer »: the one primary action of an [AppModalKind.acknowledgement],
/// or the single secondary of an [AppModalKind.listEditor]'s footer.
class AppModalClose extends StatelessWidget {
  const AppModalClose({super.key, this.primary = true});

  final bool primary;

  @override
  Widget build(BuildContext context) => AppButton(
    key: key == null ? const Key('appModalClose') : null,
    label: AppLocalizations.of(context)!.modalClose,
    variant: primary ? AppButtonVariant.primary : AppButtonVariant.secondary,
    onPressed: () => AppModal.cancel(context),
  );
}

/// « Abandonner les modifications ? »: 420 px, the lead names the form,
/// « Continuer la saisie » · ink « Abandonner ». Resolves to `true` when the
/// input is to be dropped; its own Escape returns to the form.
class _DiscardModal extends StatelessWidget {
  const _DiscardModal({required this.form});

  final String form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppModal(
      key: const Key('appModalDiscard'),
      title: l10n.modalDiscardTitle,
      subtitle: Text(l10n.modalDiscardLead(form)),
      width: AppModalSizes.w420,
      kind: AppModalKind.confirmation,
      onCancel: () => Navigator.of(context).pop(false),
      actions: [
        AppButton(
          key: const Key('appModalDiscardContinue'),
          label: l10n.modalDiscardContinue,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          key: const Key('appModalDiscardConfirm'),
          label: l10n.modalDiscardConfirm,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// How a modal's title and lead break their lines (`00` §7, Header): a title
/// balances its lines like CSS `text-wrap: balance`; a lead never leaves one
/// word alone on its last line, like `text-wrap: pretty`.
///
/// Flutter's paragraph layout is greedy, so the widget measures the text and
/// narrows the box it lays out in until the lines come out right. The text
/// stays left-aligned, so only the break points move; the modal's width never
/// changes. A child that is not a [Text] is laid out as given.
class ModalTextWrap extends StatelessWidget {
  const ModalTextWrap.balanced({super.key, required this.child})
    : _balanced = true;

  const ModalTextWrap.pretty({super.key, required this.child})
    : _balanced = false;

  final Widget child;
  final bool _balanced;

  @override
  Widget build(BuildContext context) {
    final text = child;
    if (text is! Text) return child;
    final span = text.textSpan ?? TextSpan(text: text.data);
    final style = DefaultTextStyle.of(context).style.merge(text.style);
    final scaler = text.textScaler ?? MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;
        if (!max.isFinite) return child;
        final painter = TextPainter(
          text: TextSpan(style: style, children: [span]),
          textDirection: direction,
          textScaler: scaler,
        );
        final width = _balanced
            ? _balancedWidth(painter, max)
            : _prettyWidth(painter, max, span.toPlainText());
        painter.dispose();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }

  static int _lines(TextPainter painter, double width) {
    painter.layout(maxWidth: width);
    return painter.computeLineMetrics().length;
  }

  /// The narrowest width that keeps the line count of [max]: every line then
  /// carries about the same share of the words.
  static double _balancedWidth(TextPainter painter, double max) {
    final lines = _lines(painter, max);
    if (lines <= 1) return max;
    var low = 0.0;
    var high = max;
    while (high - low > 1) {
      final mid = (low + high) / 2;
      if (_lines(painter, mid) > lines) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return high.ceilToDouble().clamp(0, max);
  }

  /// The widest width, within a third of [max], whose last line holds more
  /// than one word without adding a line.
  static double _prettyWidth(TextPainter painter, double max, String text) {
    final lines = _lines(painter, max);
    if (lines <= 1 || !_loneLastWord(painter, text)) return max;
    for (
      var width = max - AppSpacing.sm;
      width > max * 2 / 3;
      width -= AppSpacing.sm
    ) {
      if (_lines(painter, width) != lines) break;
      if (!_loneLastWord(painter, text)) return width;
    }
    return max;
  }

  /// Whether the laid-out last line holds a single word. No-break spaces
  /// (U+00A0, U+202F) join their neighbours into one word, as they do on
  /// screen.
  static bool _loneLastWord(TextPainter painter, String text) {
    final metrics = painter.computeLineMetrics();
    final last = metrics.last;
    final start = painter
        .getPositionForOffset(Offset(0, last.baseline - last.ascent / 2))
        .offset;
    return !text.substring(start).trim().contains(' ');
  }
}
