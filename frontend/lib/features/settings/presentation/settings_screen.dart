import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_info.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/currency_label.dart';
import '../../auth/presentation/display_name_card.dart';
import '../../auth/presentation/recovery_code_card.dart';
import '../application/settings_section_request.dart';
import 'ai_settings_card.dart';
import 'backup_card.dart';
import 'danger_zone_card.dart';

export '../application/settings_section_request.dart' show SettingsSection;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const path = '/settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Purely local UI state — which tab is open is not worth a provider, and
  // nothing outside this screen needs to read it.
  SettingsSection _section = SettingsSection.preferences;

  @override
  void initState() {
    super.initState();
    // Arriving from the user menu's "Edit profile": open on the requested
    // section instead of the default.
    final requested = ref.read(settingsSectionRequestProvider);
    if (requested != null) {
      _section = requested;
      _consumeRequest();
    }
  }

  /// Clears the request after this frame — a provider can't be modified while
  /// the tree is building.
  void _consumeRequest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(settingsSectionRequestProvider.notifier).consume();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Already on this screen when the request comes in: no remount, so pick it
    // up here.
    ref.listen(settingsSectionRequestProvider, (_, requested) {
      if (requested == null) return;
      setState(() => _section = requested);
      _consumeRequest();
    });

    return Padding(
      key: const Key('screen-settings'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionNav(
            active: _section,
            onSelect: (section) => setState(() => _section = section),
          ),
          const SizedBox(width: AppSpacing.lg + AppSpacing.xs),
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: switch (_section) {
                  SettingsSection.profile => const _ProfilePanel(),
                  SettingsSection.preferences => const _PreferencesPanel(),
                  SettingsSection.data => const _DataPanel(),
                  SettingsSection.about => const _AboutPanel(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.active, required this.onSelect});

  final SettingsSection active;
  final ValueChanged<SettingsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      SettingsSection.profile: l10n.settingsSectionProfile,
      SettingsSection.preferences: l10n.settingsSectionPreferences,
      SettingsSection.data: l10n.settingsSectionData,
      SettingsSection.about: l10n.settingsSectionAbout,
    };

    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in labels.entries)
            _SectionNavItem(
              key: Key('settingsSection-${entry.key.name}'),
              label: entry.value,
              selected: entry.key == active,
              onTap: () => onSelect(entry.key),
            ),
        ],
      ),
    );
  }
}

class _SectionNavItem extends StatefulWidget {
  const _SectionNavItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SectionNavItem> createState() => _SectionNavItemState();
}

class _SectionNavItemState extends State<_SectionNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.selected
        ? AppColors.iris
        : (_hovered ? AppColors.textPrimary : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hovered) => setState(() => _hovered = hovered),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            height: AppChrome.controlPillHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xs,
            ),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.irisSoft
                  : (_hovered ? AppColors.sidebarHover : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: foreground,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesPanel extends ConsumerWidget {
  const _PreferencesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeLocale = Localizations.localeOf(context);
    final currency = ref.watch(currentUserProvider)?.currency ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsCard(
          title: l10n.settingsLanguageTitle,
          note: l10n.settingsLanguageNote,
          child: AppSegmented<String>(
            value: activeLocale.languageCode,
            // Switching takes effect immediately, including the chrome — the
            // note promises that, so it must not need a save or a restart.
            onChanged: (value) =>
                ref.read(localeProvider.notifier).setLocale(Locale(value)),
            segments: [
              AppSegment(
                key: const Key('settingsLocaleFrenchOption'),
                value: 'fr',
                label: l10n.authLocaleFrench,
              ),
              AppSegment(
                key: const Key('settingsLocaleEnglishOption'),
                value: 'en',
                label: l10n.authLocaleEnglish,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gridGap),
        _SettingsCard(
          title: l10n.settingsCurrencyTitle,
          note: l10n.settingsCurrencyNote,
          child: ReadOnlyField(
            key: const Key('settingsCurrencyField'),
            value: currency.isEmpty
                ? ''
                : currencyLabel(currency, activeLocale.toString()),
          ),
        ),
        const SizedBox(height: AppSpacing.gridGap),
        _SettingsCard(
          title: l10n.settingsFormatsTitle,
          child: Row(
            children: [
              Expanded(
                child: _FormatPlate(
                  label: l10n.settingsFormatsDates,
                  child: Text(
                    DateFormat.yMd(
                      activeLocale.toString(),
                    ).format(DateTime(2026, 5, 14)),
                    key: const Key('settingsDatePreview'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: _FormatPlate(
                  label: l10n.settingsFormatsAmounts,
                  child: AmountText(
                    key: const Key('settingsAmountPreview'),
                    amountMinor: 123456,
                    currency: currency,
                    // A sample figure, not a movement.
                    colorize: false,
                    style: Theme.of(context).textTheme.bodyLarge!,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Données: the local-AI card, backup and restore under it, and the danger zone
/// last (`docs/design/09-settings.md` amendments). Database location
/// and recalculation still need endpoints the backend does not expose.
///
/// The order is the spec's and it is not arbitrary: the card that offers to
/// export the data sits above the one that deletes it, so the way out is read
/// before the way through.
class _DataPanel extends StatelessWidget {
  const _DataPanel();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AiSettingsCard(),
      SizedBox(height: AppSpacing.gridGap),
      BackupCard(),
      SizedBox(height: AppSpacing.gridGap),
      DangerZoneCard(),
    ],
  );
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _SettingsCard(
      title: l10n.settingsAboutVersion,
      note: l10n.settingsAboutPrivacy,
      child: Text(
        appVersion,
        key: const Key('settingsAppVersion'),
        style: tabularNumberStyle(Theme.of(context).textTheme.bodyLarge!),
      ),
    );
  }
}

/// The username, then the recovery code. Email edits aren't exposed yet.
class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DisplayNameCard(),
      SizedBox(height: AppSpacing.gridGap),
      RecoveryCodeCard(),
    ],
  );
}

/// One grouped card: a title, the control, and an optional note explaining the
/// rule behind it. The note is what carries permanence and scope, so a control
/// never has to look disabled to say "you can't change this".
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child, this.note});

  final String title;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          child,
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            Text(
              note!,
              style: AppTextStyles.helper.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// An inset plate showing one worked example of the active locale's formatting.
class _FormatPlate extends StatelessWidget {
  const _FormatPlate({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.sectionLabel),
          const SizedBox(height: AppSpacing.xs + 2),
          child,
        ],
      ),
    );
  }
}
