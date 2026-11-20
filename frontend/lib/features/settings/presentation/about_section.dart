import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/app_info.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/tomettes.dart';
import '../../../l10n/app_localizations.dart';
import '../application/about_info.dart';
import 'setting_row.dart';
import 'update_check_row.dart';

/// The Plan mark in the header row (`09-settings.md` §À propos).
const _markSize = 44.0;

/// Padding of the header row.
const _headerPadding = 20.0;

/// À propos: the header on tomettes, then updates, privacy, data location,
/// licence and credits as setting rows.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(),
        SizedBox(height: AppSpacing.sm),
        UpdateCheckRow(),
        _PrivacyRow(),
        _DataLocationRow(),
        _LicenseRow(),
        _CreditsRow(),
      ],
    );
  }
}

/// Mark, name and « Version {version} · {OS} » on tomettes, one of the five
/// places the texture is allowed (`00` §12, place 5).
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    // The read is local and near-instant, so loading shows an empty version
    // rather than a spinner that would only flash.
    final version = ref
        .watch(appVersionProvider)
        .when(
          data: (version) => version,
          loading: () => '',
          error: (_, _) => l10n.settingsAboutVersionUnavailable,
        );
    final os = l10n.settingsAboutOs(ref.watch(operatingSystemProvider));

    return Container(
      key: const Key('settingsAboutHeader'),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.container),
        child: Stack(
          children: [
            const Positioned.fill(child: Tomettes(fade: TomettesFade.none)),
            Padding(
              padding: const EdgeInsets.all(_headerPadding),
              child: Row(
                children: [
                  const BrandMark(size: _markSize),
                  const SizedBox(width: AppSpacing.smPlus),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BrandName(
                          size: Theme.of(
                            context,
                          ).textTheme.titleLarge!.fontSize!,
                        ),
                        Text(
                          l10n.settingsAboutVersionLine(version, os),
                          key: const Key('settingsAppVersion'),
                          style: tabularNumberStyle(
                            Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingRow(
      key: const Key('settingsAboutPrivacyRow'),
      name: l10n.settingsAboutPrivacyTitle,
      description: l10n.settingsAboutPrivacyNote,
      children: [
        Text(
          l10n.settingsAboutPrivacy,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DataLocationRow extends ConsumerWidget {
  const _DataLocationRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Loading and failure both show the empty-value placeholder and keep the
    // button off: there is no folder to open until the backend names it.
    final location = ref.watch(dataLocationProvider).value;
    final open = ref.read(openFolderProvider);

    return SettingRow(
      key: const Key('settingsAboutDataRow'),
      name: l10n.settingsAboutDataTitle,
      description: l10n.settingsAboutDataNote,
      children: [
        SelectableText(
          // The dash is the empty-value placeholder (`00` §14).
          location?.dbPath ?? '—',
          key: const Key('settingsAboutDataPath'),
          style: context.textStyles.mono.copyWith(
            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
          ),
        ),
        AppButton(
          key: const Key('settingsAboutDataOpen'),
          label: l10n.settingsAboutDataOpen,
          icon: LucideIcons300.folderOpen,
          onPressed: location == null ? null : () => open(location.dataDir),
        ),
      ],
    );
  }
}

class _LicenseRow extends ConsumerWidget {
  const _LicenseRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final open = ref.read(openExternalUrlProvider);
    final language = Localizations.localeOf(context).languageCode;

    return SettingRow(
      key: const Key('settingsAboutLicenseRow'),
      name: l10n.settingsAboutLicenseTitle,
      description: l10n.settingsAboutLicenseNote,
      children: [
        Text(
          l10n.settingsAboutLicenseName,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              key: const Key('settingsAboutSourceCode'),
              label: l10n.settingsAboutSourceCode,
              icon: LucideIcons300.externalLink,
              onPressed: () => open(sourceCodeUrl),
            ),
            AppButton(
              key: const Key('settingsAboutInstallGuide'),
              label: l10n.settingsAboutInstallGuide,
              onPressed: () => open(installGuideUrl(language)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lucide's ISC licence asks for its notice in every copy: the full text
/// ships as an asset (`core/third_party_licenses.dart`) and shows on the
/// licence page « Toutes les licences » opens; this row names it where a user
/// looks for credits.
class _CreditsRow extends StatelessWidget {
  const _CreditsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );

    TableRow line(String label, String value, {Key? key, bool first = false}) =>
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: AppSpacing.xl,
                top: first ? 0 : AppSpacing.xsPlus,
              ),
              child: Text(label, style: labelStyle),
            ),
            Padding(
              padding: EdgeInsets.only(top: first ? 0 : AppSpacing.xsPlus),
              child: Text(value, key: key, style: textTheme.bodyMedium),
            ),
          ],
        );

    return SettingRow(
      key: const Key('settingsAboutCreditsRow'),
      name: l10n.settingsAboutCreditsTitle,
      description: l10n.settingsAboutCreditsNote,
      children: [
        Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            line(
              l10n.settingsAboutCreditsIconsLabel,
              l10n.settingsAboutCreditsIcons,
              key: const Key('settingsAboutCredits'),
              first: true,
            ),
            line(
              l10n.settingsAboutCreditsFontLabel,
              l10n.settingsAboutCreditsFont,
            ),
          ],
        ),
        SettingsLink(
          key: const Key('settingsAboutAllLicenses'),
          label: l10n.settingsAboutAllLicenses,
          small: false,
          onTap: () => showLicensePage(context: context),
        ),
      ],
    );
  }
}
