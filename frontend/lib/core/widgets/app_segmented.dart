import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.key});

  final T value;
  final String label;
  final Key? key;
}

/// An inset segmented control for short, mutually exclusive choices.
///
/// Preferred over [ChoiceChip] for two or three fixed options: chips read as a
/// filter you can clear, whereas a segment track makes it obvious one option is
/// always selected.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment(
                key: segment.key,
                label: segment.label,
                selected: segment.value == value,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm + 1),
        // Selection is an instant fill swap — the spec permits no transition
        // here, and a 120ms slide would draw the eye to the control rather than
        // to what it changed.
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Fill only: a border on the active segment reads as a second
            // control nested inside the track.
            color: selected ? const Color(0x248B8CF9) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm + 1),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? AppColors.iris : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
