import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import 'goal_labels.dart';

/// Opens the create/edit goal modal. Resolves to the saved goal, or `null` when
/// the user cancelled.
Future<Goal?> showGoalForm(BuildContext context, {Goal? initial}) {
  return showDialog<Goal>(
    context: context,
    builder: (_) => GoalFormModal(initial: initial),
  );
}

/// The 480 px « Nouvel objectif » modal, reused for editing.
///
/// Deliberately short: a goal is a name, an amount, and — optionally — a date
/// it is wanted by. Nothing here asks about an account, because a goal has
/// none (`PROJECT.md` §13).
class GoalFormModal extends ConsumerStatefulWidget {
  const GoalFormModal({super.key, this.initial});

  final Goal? initial;

  @override
  ConsumerState<GoalFormModal> createState() => _GoalFormModalState();
}

class _GoalFormModalState extends ConsumerState<GoalFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initial?.name);
  final _targetController = TextEditingController();
  final _dateController = TextEditingController();

  /// Guards the one-time locale-aware fill of the amount and date fields. Done
  /// in [didChangeDependencies] because both must round-trip through the same
  /// formatters that re-parse them on submit, and those need the active locale
  /// — unavailable before the widget is mounted.
  bool _filled = false;

  late String _icon = widget.initial?.icon ?? goalIconKeys.first;
  late String _color = widget.initial?.color ?? goalColorKeys.first;

  bool _isSubmitting = false;
  String? _errorText;

  bool get _isEditing => widget.initial != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final goal = widget.initial;
    if (goal == null) return;
    final locale = Localizations.localeOf(context).toString();
    _targetController.text = NumberFormat.decimalPattern(
      locale,
    ).format(goal.targetMinor / 100);
    if (goal.targetDate case final date?) {
      _dateController.text = goalDateFormat(locale).format(date);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// The target in minor units, or `null` when the field doesn't hold a
  /// positive amount. A target is what the user is aiming at, so zero and
  /// negatives are not targets — the backend refuses them too.
  int? _parseTarget(String text, String locale) {
    try {
      final value = NumberFormat.decimalPattern(locale).parse(text.trim());
      final minor = (value.toDouble() * 100).round();
      return minor > 0 ? minor : null;
    } on FormatException {
      return null;
    }
  }

  /// `(parsed, ok)` for the optional date field: an empty field is a valid
  /// no-deadline goal, a filled one has to be a date the locale can read.
  (DateTime?, bool) _parseDate(String text, String locale) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (null, true);
    try {
      return (goalDateFormat(locale).parseStrict(trimmed), true);
    } on FormatException {
      return (null, false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final locale = Localizations.localeOf(context).toString();
    final target = _parseTarget(_targetController.text, locale);
    final (date, _) = _parseDate(_dateController.text, locale);
    if (target == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final controller = ref.read(goalsControllerProvider.notifier);
    try {
      final saved = _isEditing
          ? await controller.updateGoal(
              widget.initial!.id,
              name: _nameController.text.trim(),
              targetMinor: target,
              targetDate: date,
              icon: _icon,
              color: _color,
            )
          : await controller.create(
              name: _nameController.text.trim(),
              targetMinor: target,
              targetDate: date,
              icon: _icon,
              color: _color,
            );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeGoalError(AppLocalizations.of(context)!, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return AppModal(
      title: _isEditing ? l10n.goalFormEditTitle : l10n.goalFormCreateTitle,
      width: 480,
      actions: [
        OutlinedButton(
          key: const Key('goalFormCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.goalFormCancel),
        ),
        PrimaryButton(
          key: const Key('goalFormSubmit'),
          label: _isEditing ? l10n.goalFormSave : l10n.goalFormSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.goalFormIntro,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorText != null) ...[
              InlineBanner(key: const Key('goalFormError'), message: _errorText!),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.goalFormNameLabel,
              child: TextFormField(
                key: const Key('goalFormName'),
                controller: _nameController,
                autofocus: true,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.goalFormNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.goalFormTargetLabel,
                    child: TextFormField(
                      key: const Key('goalFormTarget'),
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => _parseTarget(value ?? '', locale) == null
                          ? l10n.goalFormTargetInvalid
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                SizedBox(
                  width: 150,
                  child: LabeledField(
                    label: l10n.goalFormDateLabel,
                    helper: l10n.goalFormDateHelp,
                    child: TextFormField(
                      key: const Key('goalFormDate'),
                      controller: _dateController,
                      validator: (value) => _parseDate(value ?? '', locale).$2
                          ? null
                          : l10n.goalFormDateInvalid,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.goalFormIconLabel,
              child: _IconPicker(
                selected: _icon,
                onSelected: (icon) => setState(() => _icon = icon),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.goalFormColorLabel,
              child: _ColorPicker(
                selected: _color,
                onSelected: (color) => setState(() => _color = color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The goal glyph, chosen from the fixed vocabulary the domain defines.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final key in goalIconKeys)
          _PickerTile(
            key: Key('goalFormIcon-$key'),
            selected: key == selected,
            onTap: () => onSelected(key),
            child: Icon(
              goalIconData(key),
              size: 18,
              color: key == selected ? AppColors.iris : AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// The goal hue, chosen from the palette's own accent and data colors.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final key in goalColorKeys)
          _PickerTile(
            key: Key('goalFormColor-$key'),
            selected: key == selected,
            onTap: () => onSelected(key),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: goalColorValue(key),
                borderRadius: BorderRadius.circular(AppRadii.xs),
              ),
            ),
          ),
      ],
    );
  }
}

/// The 38 px square both pickers are built from: an inset well that takes the
/// iris border when chosen — the same selected treatment the app's fields use
/// on focus, so "picked" reads the same here as everywhere else.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.irisSoft : AppColors.surfaceField,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.iris : AppColors.border,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
