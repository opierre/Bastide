import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goal_image_controller.dart';
import '../application/goals_controller.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';
import 'goal_image_crop_modal.dart';
import 'goal_labels.dart';
import 'goal_month_field.dart';

/// Opens the create/edit goal modal. Resolves to the saved goal, or `null` when
/// the user cancelled.
Future<Goal?> showGoalForm(BuildContext context, {Goal? initial}) {
  return showAppModal<Goal>(
    context: context,
    builder: (_) => GoalFormModal(initial: initial),
  );
}

/// The 440 px « Nouvel objectif » modal, reused for editing
/// (`11-goals.md` §Modals, proposal v6 `m-goals`): Nom, then Montant cible
/// and Échéance (facultative, a month) side by side, then Image
/// (facultative).
///
/// Deliberately short: nothing here asks about an account, because a goal
/// has none. The image is picked and cropped here but uploaded once the goal
/// is saved.
class GoalFormModal extends ConsumerStatefulWidget {
  const GoalFormModal({super.key, this.initial});

  final Goal? initial;

  @override
  ConsumerState<GoalFormModal> createState() => _GoalFormModalState();
}

class _GoalFormModalState extends ConsumerState<GoalFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  final _targetController = TextEditingController();
  late final _dateController = TextEditingController(
    text: switch (widget.initial?.targetDate) {
      final date? => formatGoalMonth(date),
      null => null,
    },
  );

  /// Guards the one-time locale-aware fill of the amount field. Done in
  /// [didChangeDependencies] because it must round-trip through the same
  /// formatter that re-parses it on submit, and that needs the active locale
  /// — unavailable before the widget is mounted.
  bool _filled = false;

  /// The banner the user cropped in this form, not yet uploaded.
  Uint8List? _image;

  /// Whether the user dropped the goal's existing banner.
  bool _removeImage = false;

  /// Why the last picked file was refused, under the image field.
  String? _imageError;

  bool _dirty = false;
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
    _targetController.text = formatMoneyInput(goal.targetMinor, locale);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// The target in minor units, or `null` when the field doesn't hold a
  /// positive amount. A target is what the user is aiming at, so zero is not
  /// one — and the field itself refuses a minus sign.
  int? _parseTarget(String text, String locale) {
    final minor = parseMoneyMinor(text, locale);
    return (minor != null && minor > 0) ? minor : null;
  }

  /// Whether the optional deadline holds something usable: an empty one is a
  /// valid no-deadline goal, a filled one has to read as a month.
  bool _monthIsValid(String text) =>
      text.trim().isEmpty || parseGoalMonth(text) != null;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final locale = Localizations.localeOf(context).toString();
    final target = _parseTarget(_targetController.text, locale);
    final date = parseGoalMonth(_dateController.text);
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
              image: _image,
              removeImage: _removeImage,
            )
          : await controller.create(
              name: _nameController.text.trim(),
              targetMinor: target,
              targetDate: date,
              image: _image,
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

  Future<void> _pickImage() async {
    final png = await pickGoalImageBytes(context, ref);
    if (!mounted) return;
    final failure = ref.read(goalImageControllerProvider).failure;
    setState(() {
      if (png != null) {
        _image = png;
        _removeImage = false;
        _imageError = null;
        _dirty = true;
      } else if (failure != null) {
        _imageError = goalImageFailureText(
          AppLocalizations.of(context)!,
          failure,
        );
      }
    });
  }

  void _dropImage() => setState(() {
    _image = null;
    _removeImage = widget.initial?.hasImage ?? false;
    _imageError = null;
    _dirty = true;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    // The goal's own currency when it has one, else the profile's. The app is
    // one currency per user, so the two only ever differ while the profile is
    // still loading.
    final currency =
        widget.initial?.currency ??
        ref.watch(currentUserProvider)?.currency ??
        '';
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('goalFormModal'),
      title: _isEditing ? l10n.goalFormEditTitle : l10n.goalFormCreateTitle,
      width: AppModalSizes.w440,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('goalFormCancel')),
        PrimaryButton(
          key: const Key('goalFormSubmit'),
          label: l10n.goalFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        onChanged: _markDirty,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            gap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.goalFormTargetLabel,
                input: MoneyField(
                  key: const Key('goalFormTarget'),
                  controller: _targetController,
                  currency: currency,
                  textAlign: TextAlign.end,
                  validator: (value) =>
                      _parseTarget(value ?? '', locale) == null
                      ? l10n.goalFormTargetInvalid
                      : null,
                ),
              ),
              end: ModalFieldCell(
                label: l10n.goalFormDateLabel,
                input: GoalMonthField(
                  key: const Key('goalFormDate'),
                  controller: _dateController,
                  hintText: l10n.goalFormDateHint,
                  calendarTooltip: l10n.goalFormDatePick,
                  onPicked: _markDirty,
                  validator: (value) => _monthIsValid(value ?? '')
                      ? null
                      : l10n.goalFormDateInvalid,
                ),
              ),
            ),
            gap,
            LabeledField(
              label: l10n.goalFormImageLabel,
              errorText: _imageError,
              child: _ImageField(
                image: _image,
                existing: _removeImage ? null : widget.initial?.imageRef,
                onPick: _isSubmitting ? null : _pickImage,
                onRemove: _isSubmitting ? null : _dropImage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The optional banner: a 36 × 24 thumbnail of the chosen (or current)
/// picture, then « Choisir une image » and, when there is one, « Retirer ».
class _ImageField extends ConsumerWidget {
  const _ImageField({
    required this.image,
    required this.existing,
    required this.onPick,
    required this.onRemove,
  });

  /// Cropped in this form, not yet uploaded.
  final Uint8List? image;

  /// The goal's current banner, unless the user dropped it.
  final GoalImageRef? existing;

  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final existing = this.existing;
    final shown =
        image ??
        (existing == null
            ? null
            : ref.watch(goalImageProvider(existing)).value);
    final hasImage = image != null || existing != null;

    return Row(
      children: [
        if (shown != null) ...[
          ClipRRect(
            key: const Key('goalFormImagePreview'),
            borderRadius: BorderRadius.circular(AppRadii.item),
            child: Image.memory(
              shown,
              width: AppGoalBanner.thumbWidth,
              height: AppGoalBanner.thumbHeight,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        AppButton(
          key: const Key('goalFormImagePick'),
          label: l10n.goalFormImagePick,
          icon: LucideIcons300.image,
          onPressed: onPick,
        ),
        if (hasImage) ...[
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            key: const Key('goalFormImageRemove'),
            label: l10n.goalFormImageRemove,
            variant: AppButtonVariant.ghost,
            onPressed: onRemove,
          ),
        ],
      ],
    );
  }
}
