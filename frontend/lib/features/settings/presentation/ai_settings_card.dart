import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_slider.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';
import 'lock_callout.dart';

/// Where « En savoir plus » sends a user with no engine: the download page of
/// Ollama, the default runtime.
///
/// The one link in the app that leaves it, and it carries nothing about the
/// user — the privacy callout two rows above stays true.
final _runtimeHelpUrl = Uri.parse('https://ollama.com/download');

/// The « IA locale » card in Settings → Données
/// (`docs/design/09-settings.md` §Amendment — IA locale, frames ③–④).
///
/// Everything it renders comes from [settingsControllerProvider]; the card
/// itself decides nothing. In particular the connection state is one value
/// from the controller rather than two booleans read here, so the status dot,
/// the model field and the helper under it can never disagree.
class AiSettingsCard extends ConsumerWidget {
  const AiSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return ref
        .watch(settingsControllerProvider)
        .when(
          // A single block rather than a [SkeletonList]: the settings panel
          // scrolls, so a ListView here would be a viewport with no bounded
          // height to lay itself out in.
          loading: () => const SkeletonPulse(
            key: Key('settingsAiLoading'),
            child: SkeletonBlock(height: 260),
          ),
          error: (_, _) => ErrorStateView(
            messageKey: const Key('settingsAiError'),
            message: l10n.settingsAiLoadFailed,
            retryLabel: l10n.settingsAiRetry,
            onRetry: () => ref.invalidate(settingsControllerProvider),
          ),
          // Keyed by nothing that changes: the text fields inside seed
          // themselves from the first state they are built with, and a key that
          // moved with the settings would reset them mid-edit.
          data: (state) => _Card(state: state),
        );
  }
}

class _Card extends ConsumerStatefulWidget {
  const _Card({required this.state});

  final SettingsState state;

  @override
  ConsumerState<_Card> createState() => _CardState();
}

class _CardState extends ConsumerState<_Card> {
  late final _baseUrl = TextEditingController(
    text: widget.state.settings.inferenceBaseUrl,
  );
  late final _modelTag = TextEditingController(
    text: widget.state.settings.modelTag ?? '',
  );

  @override
  void dispose() {
    _baseUrl.dispose();
    _modelTag.dispose();
    super.dispose();
  }

  SettingsController get _controller =>
      ref.read(settingsControllerProvider.notifier);

  /// Puts a tag picked off the engine's list into the field the user could also
  /// have typed it into — one field, two ways in, so the manual entry and the
  /// list never become two competing values.
  void _pickModel(String tag) {
    _modelTag.value = TextEditingValue(
      text: tag,
      selection: TextSelection.collapsed(offset: tag.length),
    );
    _controller.setModelTag(tag);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;

    return AppCard(
      key: const Key('settingsAiCard'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            enabled: state.settings.aiEnabled,
            onChanged: (value) => _controller.setAiEnabled(value),
          ),
          const SizedBox(height: AppSpacing.md),
          // The card's centerpiece, and unconditional: what the user is being
          // asked to opt into is exactly the promise this makes, so it is
          // present whether the toggle is on or off.
          LockCallout(
            key: const Key('settingsAiPrivacy'),
            message: l10n.settingsAiPrivacy,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 13,
                child: LabeledField(
                  label: l10n.settingsAiBaseUrlLabel,
                  helper: l10n.settingsAiBaseUrlHelp,
                  errorText: state.baseUrlError == null
                      ? null
                      : l10n.settingsAiBaseUrlRejected,
                  child: FocusGlow(
                    child: TextField(
                      key: const Key('settingsAiBaseUrlField'),
                      controller: _baseUrl,
                      style: AppTextStyles.mono.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: state.baseUrlError == null
                          ? null
                          : errorFieldDecoration(),
                      onChanged: _controller.setBaseUrl,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 10,
                child: _ModelField(
                  controller: _modelTag,
                  connection: state.connection,
                  models: state.models,
                  onTyped: _controller.setModelTag,
                  onPicked: _pickModel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            // The slider works in whole percents and the label states them;
            // the `[0,1]` real underneath never reaches the screen.
            label: l10n.settingsAiThresholdLabel(state.thresholdPercent / 100),
            helper: l10n.settingsAiThresholdHelp,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppSlider(
                key: const Key('settingsAiThresholdSlider'),
                value: state.thresholdPercent.toDouble(),
                onChanged: (value) =>
                    _controller.setThresholdPercent(value.round()),
                semanticFormatter: (value) =>
                    l10n.settingsAiThresholdLabel(value / 100),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          _StatusRow(
            connection: state.connection,
            modelCount: state.models.length,
            isProbing: state.isProbing,
            onTest: () => _controller.probe(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsAiTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.settingsAiSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppToggle(
          key: const Key('settingsAiToggle'),
          value: enabled,
          onChanged: onChanged,
          semanticLabel: l10n.settingsAiToggleLabel,
        ),
      ],
    );
  }
}

/// The model tag: a monospace field the user can type into, with the engine's
/// own list one tap away.
///
/// Editable rather than a plain [AppSelect] because a runtime can serve a tag
/// it does not advertise, and a closed list would leave that user with no way
/// in. With no engine it becomes the dashed read-only dash the mockup draws —
/// never an empty dropdown, which offers a choice that does not exist.
class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.controller,
    required this.connection,
    required this.models,
    required this.onTyped,
    required this.onPicked,
  });

  final TextEditingController controller;
  final InferenceConnection connection;
  final List<String> models;
  final ValueChanged<String> onTyped;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (connection.isUnreachable) {
      return LabeledField(
        label: l10n.settingsAiModelLabel,
        helper: l10n.settingsAiModelUnavailable,
        child: const ReadOnlyField(
          key: Key('settingsAiModelReadOnly'),
          value: '—',
        ),
      );
    }

    return LabeledField(
      label: l10n.settingsAiModelLabel,
      helper: l10n.settingsAiModelHelp,
      child: FocusGlow(
        child: TextField(
          key: const Key('settingsAiModelField'),
          controller: controller,
          style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
          onChanged: onTyped,
          decoration: InputDecoration(
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: models.isEmpty
                ? null
                : _ModelMenu(models: models, onPicked: onPicked),
          ),
        ),
      ),
    );
  }
}

class _ModelMenu extends StatelessWidget {
  const _ModelMenu({required this.models, required this.onPicked});

  final List<String> models;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfacePopover),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(AppShadows.popoverShadow),
        elevation: WidgetStatePropertyAll(AppShadows.popoverElevation),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.inset)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
      menuChildren: [
        for (final tag in models)
          MenuItemButton(
            key: Key('settingsAiModelOption-$tag'),
            onPressed: () => onPicked(tag),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, 32)),
              overlayColor: WidgetStatePropertyAll(AppColors.overlayWash),
            ),
            child: Text(
              tag,
              style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
            ),
          ),
      ],
      builder: (context, menu, _) => IconButton(
        key: const Key('settingsAiModelMenu'),
        tooltip: l10n.settingsAiModelChoose,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(
          Icons.expand_more_rounded,
          size: 17,
          color: AppColors.iris,
        ),
      ),
    );
  }
}

/// The row behind the divider: what the engine is doing, and the button that
/// asks it again.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.connection,
    required this.modelCount,
    required this.isProbing,
    required this.onTest,
  });

  final InferenceConnection connection;
  final int modelCount;
  final bool isProbing;
  final VoidCallback onTest;

  Color get _dotColor => switch (connection) {
    InferenceConnection.reachable => AppColors.positive,
    InferenceConnection.unreachable => AppColors.warning,
    InferenceConnection.disabled => AppColors.textDisabled,
  };

  String _label(AppLocalizations l10n) => switch (connection) {
    InferenceConnection.reachable => l10n.settingsAiStatusConnected(modelCount),
    InferenceConnection.unreachable => l10n.settingsAiStatusUnreachable,
    InferenceConnection.disabled => l10n.settingsAiStatusDisabled,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Container(
          key: const Key('settingsAiStatusDot'),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            _label(l10n),
            key: const Key('settingsAiStatusLabel'),
            style: AppTextStyles.helper.copyWith(color: _dotColor),
          ),
        ),
        if (connection.isUnreachable) ...[
          const SizedBox(width: AppSpacing.sm),
          _LearnMoreLink(label: l10n.settingsAiLearnMore),
        ],
        const Spacer(),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: 34,
          child: OutlinedButton(
            key: const Key('settingsAiTestButton'),
            onPressed: isProbing ? null : onTest,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs),
              ),
            ),
            child: isProbing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(l10n.settingsAiTesting),
                    ],
                  )
                : Text(l10n.settingsAiTest),
          ),
        ),
      ],
    );
  }
}

/// The underlined iris link the no-engine frame draws. Hands off to the
/// runtime's own download page in the default browser — the app has no
/// in-product documentation to send the user to instead.
class _LearnMoreLink extends StatelessWidget {
  const _LearnMoreLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const Key('settingsAiLearnMore'),
        onTap: () =>
            launchUrl(_runtimeHelpUrl, mode: LaunchMode.externalApplication),
        child: Text(
          label,
          style: AppTextStyles.helper.copyWith(
            color: AppColors.iris,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.iris,
          ),
        ),
      ),
    );
  }
}
