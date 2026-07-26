import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The top bar's search control: a 38px raised pill with a leading magnifier.
///
/// Width is a parameter because each panel spec sizes it to its own bar (230 on
/// accounts, 250 on the dashboard, 300 on transactions) — everything else about
/// it is fixed so the control reads as one thing across the app.
class SearchPill extends StatefulWidget {
  const SearchPill({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = 230,
    this.initialValue = '',
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final double width;
  final String initialValue;

  @override
  State<SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<SearchPill> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A maximum rather than a fixed width: the frame is designed at 1440, but
    // the window can be dragged narrower, and the pill should give up space
    // before the top bar starts clipping.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.width,
        maxHeight: AppChrome.controlPillHeight,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: true,
          fillColor: AppColors.surfaceRaised,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          prefixIcon: const Icon(Icons.search_rounded, size: 16),
          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          border: _border(AppColors.border),
          enabledBorder: _border(AppColors.border),
          focusedBorder: _border(AppColors.focusRing),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
    borderSide: BorderSide(color: color),
  );
}
