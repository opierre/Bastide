import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'focus_ring.dart';

/// One tab of an [AppTabs].
@immutable
class AppTab<T> {
  const AppTab({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Already formatted for the locale; follows the label in `textTertiary`.
  final String? count;
}

/// The tabs of `docs/design/00-design-system.md` §6: a 40 px row on a `line`
/// hairline; tabs padded 10 0, 20 px apart, 13 `textSecondary`; the selected
/// one in `text` 500 over a 2 px `text` underline.
class AppTabs<T> extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
  });

  final List<AppTab<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  /// Space between two tabs.
  static const gap = 20.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.tab,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            _Tab(
              key: Key('appTab-$i'),
              tab: tabs[i],
              selected: tabs[i].value == value,
              onTap: () => onChanged(tabs[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab<T> extends StatefulWidget {
  const _Tab({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab<T> tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Tab<T>> createState() => _TabState<T>();
}

class _TabState<T> extends State<_Tab<T>> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme.bodyMedium!;
    final count = widget.tab.count;

    return Semantics(
      button: true,
      selected: widget.selected,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: widget.selected ? colors.text : Colors.transparent,
                  ),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: widget.tab.label),
                    if (count != null)
                      TextSpan(
                        text: ' $count',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                style: style.copyWith(
                  color: widget.selected ? colors.text : colors.textSecondary,
                  fontWeight: widget.selected
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
