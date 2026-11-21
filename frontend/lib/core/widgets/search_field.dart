import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'labeled_field.dart';

/// The search field of `docs/design/00-design-system.md` §6: 240 × 28, a
/// `search` icon, a placeholder, and the `Ctrl K` hint in a 1 px `lineStrong`
/// box (radius 4, 11 px). `Ctrl K` focuses the field from anywhere while it is
/// on screen.
///
/// The hint gives way to a clear button once there is text to clear.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = AppSizes.searchField,
    this.initialValue = '',
    this.value,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  /// A maximum: the field gives up width before the title bar clips.
  final double width;
  final String initialValue;

  /// The text the field shows, when it mirrors state held elsewhere (a
  /// filter that a link or a reset can change): the field follows it whenever
  /// it differs from what is typed. `null` leaves the field to its own text.
  final String? value;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final _controller = TextEditingController(
    text: widget.value ?? widget.initialValue,
  );
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChanged);
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    // Typing echoes back the same text, so only an outside change lands here.
    if (value != null && value != _controller.text) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// `Ctrl K` (or `Cmd K` on macOS) focuses the field.
  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    return true;
  }

  void _handleTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide(color: color),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.width,
        maxHeight: AppSizes.toolbarSelect,
      ),
      child: FocusGlow(
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          style: textTheme.bodyMedium,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: widget.hint,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              height: AppSizes.toolbarSelect,
            ),
            prefixIcon: Icon(
              LucideIcons300.search,
              size: AppSizes.iconSmall,
              color: colors.textTertiary,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: AppSizes.toolbarSelect,
              minHeight: AppSizes.toolbarSelect - 2,
            ),
            suffixIcon: _hasText
                ? IconButton(
                    key: const Key('searchFieldClear'),
                    icon: const Icon(LucideIcons300.x),
                    iconSize: AppSizes.iconSmall,
                    padding: EdgeInsets.zero,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                    onPressed: _clear,
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xsPlus),
                    child: _ShortcutHint(label: l10n.searchShortcutHint),
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: AppSizes.toolbarSelect - 4,
              maxHeight: AppSizes.toolbarSelect - 2,
            ),
            border: border(colors.lineStrong),
            enabledBorder: border(colors.lineStrong),
            focusedBorder: border(colors.accent),
          ),
        ),
      ),
    );
  }
}

/// The `Ctrl K` box at the field's end.
class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: Container(
        key: const Key('searchFieldShortcut'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.item),
          border: Border.all(color: context.colors.lineStrong),
        ),
        child: Text(label, style: context.textStyles.helper),
      ),
    );
  }
}
