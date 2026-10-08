import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/profile_controllers.dart';
import '../domain/display_name.dart';

/// The « Nom d'utilisateur » card in Settings › Profil. The display name is
/// also a login name, so the card says so rather than presenting it as a mere
/// label.
class DisplayNameCard extends ConsumerWidget {
  const DisplayNameCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final name = ref.watch(currentUserProvider)?.displayName ?? '';

    return AppCard(
      key: const Key('settingsDisplayNameCard'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsProfileNameTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.settingsProfileNameSubtitle(name),
                  style: AppTextStyles.helper.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton(
            key: const Key('settingsDisplayNameButton'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => DisplayNameModal(initialName: name),
            ),
            child: Text(l10n.settingsProfileNameButton),
          ),
        ],
      ),
    );
  }
}

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
      width: 480,
      actions: [
        OutlinedButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settingsProfileNameModalCancel),
        ),
        PrimaryButton(
          key: const Key('displayNameModalSave'),
          label: l10n.settingsProfileNameModalSave,
          isLoading: isSaving,
          onPressed: _canSave ? _save : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settingsProfileNameModalLead,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: l10n.authDisplayNameLabel,
            helper: l10n.authDisplayNameHelper,
            errorText: errorText,
            child: TextFormField(
              key: const Key('displayNameModalField'),
              controller: _nameController,
              autofocus: true,
              autofillHints: const [AutofillHints.newUsername],
              decoration: errorText != null ? errorFieldDecoration() : null,
              onFieldSubmitted: (_) => isSaving || !_canSave ? null : _save(),
            ),
          ),
        ],
      ),
    );
  }
}
