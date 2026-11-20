import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/profile_controllers.dart';
import '../domain/display_name.dart';

/// « Changer de nom d'utilisateur », opened from the username row of
/// Settings › Profil. The display name is also a login name, so the lead says
/// the new one replaces the old for signing in.
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
    // The save button's enabled state and the format error follow the field.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      isValidDisplayName(_nameController.text) &&
      _nameController.text.trim().toLowerCase() != widget.initialName;

  Future<void> _save() async {
    await ref
        .read(displayNameControllerProvider.notifier)
        .save(displayName: _nameController.text.trim());
    if (!mounted) return;
    if (!ref.read(displayNameControllerProvider).hasError) {
      Navigator.of(context).pop();
    }
  }

  String? _errorText(AppLocalizations l10n, AsyncValue<void> state) {
    final text = _nameController.text;
    if (text.isNotEmpty && !isValidDisplayName(text)) {
      return l10n.authDisplayNameInvalid;
    }
    if (!state.hasError) return null;
    return state.error is ApiFailure &&
            (state.error! as ApiFailure).code == 'DISPLAY_NAME_TAKEN'
        ? l10n.authDisplayNameTaken
        : l10n.authErrorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(displayNameControllerProvider);
    final isSaving = state.isLoading;
    final errorText = _errorText(l10n, state);

    return AppModal(
      title: l10n.settingsProfileNameModalTitle,
      width: 420,
      actions: [
        AppButton(
          label: l10n.settingsProfileNameModalCancel,
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
        ),
        PrimaryButton(
          key: const Key('displayNameModalSave'),
          label: l10n.settingsProfileNameModalSave,
          isLoading: isSaving,
          onPressed: _canSave ? _save : null,
        ),
      ],
      subtitle: Text(l10n.settingsProfileNameModalLead),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: l10n.authDisplayNameLabel,
            helper: l10n.authDisplayNameHelper,
            errorText: errorText,
            child: TextFormField(
              key: const Key('displayNameModalField'),
              controller: _nameController,
              autofocus: true,
              autofillHints: const [AutofillHints.newUsername],
              decoration: errorText != null
                  ? errorFieldDecoration(context)
                  : null,
              onFieldSubmitted: (_) => isSaving || !_canSave ? null : _save(),
            ),
          ),
        ],
      ),
    );
  }
}
