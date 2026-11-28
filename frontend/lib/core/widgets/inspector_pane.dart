import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'motion/appear_transition.dart';

/// The inspector pane of `docs/design/00-design-system.md` §7: the right
/// pane, 440 px, on `rail` behind a left `line` hairline, padding 24; its
/// [blocks] 16 px apart, separated by hairlines. It shows the row selected
/// in the list on its left (Transactions, Objectifs, Placements).
///
/// When [selection] changes, the new content fades in over `enter`
/// (`00` §13), a fade that reduced motion keeps. The pane itself never
/// moves.
class InspectorPane extends StatelessWidget {
  const InspectorPane({
    super.key,
    required this.selection,
    required this.blocks,
    this.header,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  /// Identifies what the pane shows: the selected row's id.
  final Object selection;

  final List<Widget> blocks;

  /// Drawn edge to edge above the padded blocks, ignoring the padding: the
  /// goal banner (`11-goals.md`).
  final Widget? header;

  /// Around the blocks; 24 on every side unless a panel spec says otherwise.
  final EdgeInsetsGeometry padding;

  /// Between two blocks, on either side of their hairline.
  static const blockGap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: AppSizes.inspector,
      decoration: BoxDecoration(
        color: colors.rail,
        border: Border(left: BorderSide(color: colors.line)),
      ),
      child: AnimatedSwitcher(
        duration: MotionSpec.of(context).duration(MotionKind.appear),
        // The old content stays fully drawn under the new one until it is
        // removed; only the new one fades in, on the shared curve.
        switchOutCurve: const Threshold(0),
        transitionBuilder: (child, animation) => AppearTransition.driven(
          animation: animation,
          travel: false,
          child: child,
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: SingleChildScrollView(
          key: ValueKey(selection),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?header,
              Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < blocks.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: blockGap,
                          ),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: colors.line,
                          ),
                        ),
                      blocks[i],
                    ],
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
