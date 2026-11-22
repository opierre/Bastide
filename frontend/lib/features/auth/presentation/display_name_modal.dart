import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/profile_controllers.dart';
import '../domain/display_name.dart';

/// « Changer de nom d’utilisateur », the 420 px modal opened from the
/// username row of Settings › Profil (`09-settings.md`, Username modal). The
/// display name is also a login name, so the lead says the new one replaces
/// the old for signing in.
///
/// A malformed or taken name is refused under the field; any other failure
/// is the frame's save banner, the input kept.
class DisplayNameModal extends ConsumerStatefulWidget {
  const DisplayNameModal({super.key, required this.initialName});

  final String initialName;

  @override
  ConsumerState<DisplayNameModal> createState() => _DisplayNameModalState();
}

class _DisplayNameModalState extends ConsumerState<DisplayNameModal> {
  late final _nameController = TextEditingController(text: widget.initialName);

  @override
  void initState() {
    super.initState();
    // The save button, the format error and the dirty state follow the field.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      isValidDisplayName(_nameController.text) &&
      normalizeDisplayName(_nameController.text) != widget.initialName;

  Future<void> _save() async {
    if (!_canSave || ref.read(displayNameControllerProvider).isLoading) {
      return;
    }
    await ref
        .read(displayNameControllerProvider.notifier)
        .save(displayName: normalizeDisplayName(_nameController.text));
    if (!mounted) return;
    if (!ref.read(displayNameControllerProvider).hasError) {
      Navigator.of(context).pop();
    }
  }

  static bool _isTaken(Object? error) =>
      error is ApiFailure && error.code == 'DISPLAY_NAME_TAKEN';

  String? _fieldError(AppLocalizations l10n, AsyncValue<void> state) {
    final text = _nameController.text;
    if (text.isNotEmpty && !isValidDisplayName(text)) {
      return l10n.authDisplayNameInvalid;
    }
    return state.hasError && _isTaken(state.error)
        ? l10n.authDisplayNameTaken
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(displayNameControllerProvider);
    final isSaving = state.isLoading;
    final fieldError = _fieldError(l10n, state);

    return AppModal(
      key: const Key('displayNameModal'),
      title: l10n.settingsProfileNameModalTitle,
      subtitle: Text(l10n.settingsProfileNameModalLead),
      width: AppModalSizes.w420,
      dirty: _nameController.text != widget.initialName,
      busy: isSaving,
      saveError: state.hasError && !_isTaken(state.error)
          ? l10n.authErrorGeneric
          : null,
      onSubmit: _save,
      actions: [
        const AppModalCancel(key: Key('displayNameModalCancel')),
        PrimaryButton(
          key: const Key('displayNameModalSave'),
          label: l10n.settingsProfileNameModalSave,
          isLoading: isSaving,
          onPressed: _canSave ? _save : null,
        ),
      ],
      child: LabeledField(
        label: l10n.authDisplayNameLabel,
        helper: l10n.authDisplayNameHelper,
        errorText: fieldError,
        child: TextFormField(
          key: const Key('displayNameModalField'),
          controller: _nameController,
          autofillHints: const [AutofillHints.newUsername],
          decoration: fieldError != null ? errorFieldDecoration(context) : null,
        ),
      ),
    );
  }
}
