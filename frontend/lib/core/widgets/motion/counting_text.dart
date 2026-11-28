import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import 'measure_tween.dart';

/// A figure that counts from its old value to its new one through
/// [MeasureTween] (`00` §13): only the figure that heads a block counts;
/// amounts in rows change at once.
///
/// The value is an integer (money in minor units, a rate in basis points)
/// and stays one on every frame: [format] turns each step into the text for
/// the user's locale. Tabular numerals keep the digits from shifting while
/// they count. A screen reader hears the final value only.
class CountingText extends StatelessWidget {
  const CountingText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final int value;

  /// Formats one step of the count, per locale.
  final String Function(int value) format;

  /// Merged over the ambient text style, then set in tabular numerals.
  final TextStyle? style;

  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final resolved = tabularNumberStyle(
      DefaultTextStyle.of(context).style.merge(style),
    );
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: MeasureTween<int>(
        value: value,
        tween: IntTween.new,
        builder: (context, shown, _) => Text(
          format(shown),
          style: resolved,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
      ),
    );
  }
}
