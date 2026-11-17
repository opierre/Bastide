import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The heading of a section inside a panel
/// (`docs/design/00-design-system.md` §7): 13/600, with an optional right
/// side on the same line (a secondary figure, a link, a segmented control or
/// a chart legend). Sits 8–12 px above its content; [SectionHeading] carries
/// the 8 px itself.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.smPlus),
            trailing!,
          ],
        ],
      ),
    );
  }
}
