import 'package:flutter/material.dart';

/// A chart's hover card: the hovered point's [message], dressed as the app's tooltips are
/// (the theme's [TooltipThemeData]) so every chart's readout looks the same.
///
/// It is only the card. Each chart decides where it goes, so it can keep clear of what
/// the reader is looking at, and shows it instantly rather than after [Tooltip]'s delay.
class ChartTooltip extends StatelessWidget {
  const ChartTooltip({super.key, required this.message});

  final InlineSpan message;

  @override
  Widget build(BuildContext context) {
    final theme = TooltipTheme.of(context);
    return DecoratedBox(
      decoration: theme.decoration ?? const BoxDecoration(),
      child: Padding(
        padding: theme.padding ?? EdgeInsets.zero,
        child: Text.rich(TextSpan(children: [message]), style: theme.textStyle),
      ),
    );
  }
}
