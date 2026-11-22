import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/app_slider.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';
import 'setting_row.dart';

/// Where « En savoir plus » sends a user with no engine: the download page of
/// Ollama, the default runtime.
///
/// The one link in the app that leaves it, and it carries nothing about the
/// user, so the privacy promise in the row above stays true.
final _runtimeHelpUrl = Uri.parse('https://ollama.com/download');

/// The address field takes 1.3 parts of the engine line, the model 1.
const _addressFlex = 13;
const _modelFlex = 10;

/// « IA locale » in Settings › Données: the opt-in toggle, the engine line and
/// the confidence threshold, as setting rows.
///
/// Everything it renders comes from [settingsControllerProvider]; the group
/// itself decides nothing. The connection state is one value from the
/// controller rather than two booleans read here, so the status text, the
/// model field and its helper can never disagree.
class AiSettingsGroup extends ConsumerWidget {
  const AiSettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(title: l10n.settingsAiTitle, first: true),
        ref
            .watch(settingsControllerProvider)
            .when(
              loading: () =>
                  const SettingsSkeleton(key: Key('settingsAiLoading')),
              error: (_, _) => ErrorStateView(
                messageKey: const Key('settingsAiError'),
                message: l10n.settingsAiLoadFailed,
                retryLabel: l10n.settingsAiRetry,
                onRetry: () => ref.invalidate(settingsControllerProvider),
              ),
              // Keyed by nothing that changes: the text fields inside seed
              // themselves from the first state they are built with, and a
              // key that moved with the settings would reset them mid-edit.
              data: (state) => _Rows(state: state),
            ),
      ],
    );
  }
}

class _Rows extends ConsumerStatefulWidget {
  const _Rows({required this.state});

  final SettingsState state;

  @override
  ConsumerState<_Rows> createState() => _RowsState();
}

class _RowsState extends ConsumerState<_Rows> {
  late final _baseUrl = TextEditingController(
    text: widget.state.settings.inferenceBaseUrl,
  );
  late final _modelTag = TextEditingController(
    text: widget.state.settings.modelTag ?? '',
  );

  /// Follows a value the controller changed on the user's behalf: « Utiliser
  /// Ollama » rewrites the address. While the user types, the state already
  /// holds what they typed, so the two never differ and nothing is reset
  /// mid-edit.
  @override
  void didUpdateWidget(covariant _Rows oldWidget) {
    super.didUpdateWidget(oldWidget);
    final baseUrl = widget.state.settings.inferenceBaseUrl;
    if (baseUrl != oldWidget.state.settings.inferenceBaseUrl &&
        baseUrl != _baseUrl.text) {
      _baseUrl.text = baseUrl;
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _modelTag.dispose();
    super.dispose();
  }

  SettingsController get _controller =>
      ref.read(settingsControllerProvider.notifier);

  /// Puts a tag picked off the engine's list into the field the user could
  /// also have typed it into: one field, two ways in, so the manual entry and
  /// the list never become two competing values.
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
    final enabled = state.settings.aiEnabled;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );

    return Column(
      key: const Key('settingsAiCard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The description is the privacy promise itself: what the user is
        // asked to opt into is exactly what it says, so it is there whether
        // the toggle is on or off.
        SettingRow(
          key: const Key('settingsAiPrivacy'),
          name: l10n.settingsAiSubtitle,
          description: l10n.settingsAiPrivacy,
          children: [
            AppToggle(
              key: const Key('settingsAiToggle'),
              value: enabled,
              onChanged: _controller.setAiEnabled,
              semanticLabel: l10n.settingsAiToggleLabel,
            ),
          ],
        ),
        SettingRow(
          key: const Key('settingsAiEngineRow'),
          name: l10n.settingsAiEngineTitle,
          description: l10n.settingsAiBaseUrlHelp,
          enabled: enabled,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _addressFlex,
                  child: Semantics(
                    label: l10n.settingsAiBaseUrlLabel,
                    child: FocusGlow(
                      child: TextField(
                        key: const Key('settingsAiBaseUrlField'),
                        controller: _baseUrl,
                        style: context.textStyles.mono.copyWith(
                          color: context.colors.text,
                        ),
                        decoration: state.baseUrlError == null
                            ? null
                            : errorFieldDecoration(context),
                        onChanged: _controller.setBaseUrl,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: _modelFlex,
                  child: _ModelField(
                    controller: _modelTag,
                    connection: state.connection,
                    models: state.models,
                    onTyped: _controller.setModelTag,
                    onPicked: _pickModel,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  key: const Key('settingsAiTestButton'),
                  label: l10n.settingsAiTest,
                  loadingLabel: l10n.settingsAiTesting,
                  isLoading: state.isProbing,
                  onPressed: _controller.probe,
                ),
              ],
            ),
            if (state.baseUrlError != null)
              FieldHelper(
                key: const Key('settingsAiBaseUrlRejected'),
                text: l10n.settingsAiBaseUrlRejected,
                isError: true,
              )
            else if (state.connection.isUnreachable)
              FieldHelper(text: l10n.settingsAiModelUnavailable),
            _Status(
              connection: state.connection,
              modelCount: state.models.length,
            ),
            if (state.offersOllama)
              InlineBanner(
                key: const Key('settingsAiOllamaPlate'),
                tone: BannerTone.info,
                message: l10n.settingsAiOllamaFound(
                  state.ollama!.models.length,
                ),
                actions: [
                  AppButton(
                    key: const Key('settingsAiOllamaUse'),
                    label: l10n.settingsAiOllamaUse,
                    onPressed: _controller.useOllama,
                  ),
                ],
              ),
          ],
        ),
        SettingRow(
          key: const Key('settingsAiThresholdRow'),
          name: l10n.settingsAiThresholdTitle,
          description: l10n.settingsAiThresholdHelp,
          enabled: enabled,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The slider works in whole percents; the `[0,1]` real
                // underneath never reaches the screen.
                AppSlider(
                  key: const Key('settingsAiThresholdSlider'),
                  value: state.thresholdPercent.toDouble(),
                  width: SettingRowMetrics.sliderWidth,
                  onChanged: (value) =>
                      _controller.setThresholdPercent(value.round()),
                  semanticFormatter: (value) => percent.format(value / 100),
                ),
                SizedBox(
                  width: SettingRowMetrics.sliderValueWidth,
                  child: Text(
                    percent.format(state.thresholdPercent / 100),
                    key: const Key('settingsAiThresholdValue'),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The model tag: a monospace field the user can type into, with the engine's
/// own list one click away.
///
/// Editable rather than a plain select because a runtime can serve a tag it
/// does not advertise, and a closed list would leave that user with no way
/// in. With no engine it is disabled: an empty dropdown would offer a choice
/// that does not exist.
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
    final unreachable = connection.isUnreachable;

    return Semantics(
      label: l10n.settingsAiModelLabel,
      child: Opacity(
        opacity: unreachable ? 0.45 : 1,
        child: FocusGlow(
          child: TextField(
            key: Key(
              unreachable ? 'settingsAiModelReadOnly' : 'settingsAiModelField',
            ),
            controller: controller,
            enabled: !unreachable,
            style: context.textStyles.mono.copyWith(color: context.colors.text),
            onChanged: onTyped,
            decoration: InputDecoration(
              suffixIconConstraints: const BoxConstraints(
                minWidth: AppSizes.formField,
              ),
              suffixIcon: _ModelMenu(
                models: unreachable ? const [] : models,
                onPicked: onPicked,
              ),
            ),
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
    final chevron = Icon(
      LucideIcons300.chevronDown,
      size: AppSizes.iconSmall,
      color: context.colors.textTertiary,
    );
    if (models.isEmpty) return chevron;

    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: AppPopover.menuStyle(context),
      menuChildren: [
        for (final tag in models)
          AppMenuItem(
            key: Key('settingsAiModelOption-$tag'),
            label: tag,
            onPressed: () => onPicked(tag),
          ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: l10n.settingsAiModelChoose,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: const Key('settingsAiModelMenu'),
            behavior: HitTestBehavior.opaque,
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            child: SizedBox.square(
              dimension: AppSizes.formField,
              child: chevron,
            ),
          ),
        ),
      ),
    );
  }
}

/// What the engine is doing, under the engine line: « Connecté · 3 modèles
/// disponibles », or no engine at this address with a way to get one.
/// Nothing while the AI is off: the rows are disabled and say enough.
class _Status extends StatelessWidget {
  const _Status({required this.connection, required this.modelCount});

  final InferenceConnection connection;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caption = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary);

    return switch (connection) {
      InferenceConnection.disabled => const SizedBox.shrink(),
      InferenceConnection.reachable => Wrap(
        key: const Key('settingsAiStatus'),
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusText(
            key: const Key('settingsAiStatusLabel'),
            label: l10n.settingsAiConnected,
            tone: StatusTone.positive,
          ),
          Text(l10n.settingsAiModelCount(modelCount), style: caption),
        ],
      ),
      InferenceConnection.unreachable => Wrap(
        key: const Key('settingsAiStatus'),
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusText(
            key: const Key('settingsAiStatusLabel'),
            label: l10n.settingsAiStatusUnreachable,
            tone: StatusTone.warning,
          ),
          const _LearnMoreLink(),
        ],
      ),
    };
  }
}

/// Hands off to the runtime's own download page in the default browser: the
/// app has no in-product documentation to send the user to instead.
class _LearnMoreLink extends StatelessWidget {
  const _LearnMoreLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppLink(
      key: const Key('settingsAiLearnMore'),
      label: l10n.settingsAiLearnMore,
      onTap: () =>
          launchUrl(_runtimeHelpUrl, mode: LaunchMode.externalApplication),
    );
  }
}
