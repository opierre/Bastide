import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/networth_summary.dart';

/// « avril 2026 » — a month named in full, as the hero caption reads it.
DateFormat networthMonthFormat(String locale) => DateFormat.yMMMM(locale);

/// Row 1 of the Synthèse view (`15-synthese.md`): the net-worth hero, Actif and
/// Passif, grid `1.5fr 1fr 1fr`.
class NetworthSummaryRow extends StatelessWidget {
  const NetworthSummaryRow({super.key, required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 150, child: _NetWorthHero(summary: summary)),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(flex: 100, child: _AssetsCard(summary: summary)),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(flex: 100, child: _LiabilitiesCard(summary: summary)),
        ],
      ),
    );
  }
}

/// The iris-tinted hero. Net worth is a **neutral** figure, like the
/// dashboard's Net: never green when positive, and a negative one keeps the
/// neutral ink with its U+2212 — it is a measurement, not a verdict.
class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final delta = summary.monthDeltaMinor;
    final series = summary.series;

    return AppCard(
      key: const Key('networthHero'),
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      gradient: AppColors.irisTintGradient,
      border: Border.all(color: AppColors.irisBorderStrong),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.networthHeroLabel.toUpperCase(),
            style: AppTextStyles.statLabel.copyWith(color: AppColors.iris),
          ),
          const SizedBox(height: AppSpacing.sm),
          AmountText(
            key: const Key('networthValue'),
            amountMinor: summary.netWorthMinor,
            currency: summary.currency,
            colorize: false,
            maxLines: 1,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          if (delta != null && series.length >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                NetworthDeltaPill(
                  deltaMinor: delta,
                  currency: summary.currency,
                ),
                // Only what the API states: the month the delta is measured
                // against, and that property values did not move. Whether the
                // accounts or the loans moved it is not in the response.
                Text(
                  summary.propertyValuesHeldFlat
                      ? l10n.networthDeltaCaptionFlat(
                          networthMonthFormat(
                            locale,
                          ).format(series[series.length - 2].month),
                        )
                      : l10n.networthDeltaCaption(
                          networthMonthFormat(
                            locale,
                          ).format(series[series.length - 2].month),
                        ),
                  key: const Key('networthDeltaCaption'),
                  style: AppTextStyles.helper,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The month delta pill: iris 14 % / iris in **both** directions, with the
/// triangle turned for the direction (`15-synthese.md` §Notes). A net-worth
/// move is not income, so it never takes the semantic green or red.
class NetworthDeltaPill extends StatelessWidget {
  const NetworthDeltaPill({
    super.key,
    required this.deltaMinor,
    required this.currency,
  });

  final int deltaMinor;
  final String currency;

  /// The pill's fill: iris at 14 %.
  static final fill = AppColors.iris.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Container(
      key: const Key('networthDeltaPill'),
      height: 22,
      padding: const EdgeInsets.only(left: 4, right: AppSpacing.sm),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotatedBox(
            key: const Key('networthDeltaTriangle'),
            quarterTurns: deltaMinor < 0 ? 2 : 0,
            child: const Icon(
              Icons.arrow_drop_up_rounded,
              size: 18,
              color: AppColors.iris,
            ),
          ),
          Text(
            formatAmount(
              amountMinor: deltaMinor,
              currency: currency,
              locale: locale,
              showPositiveSign: true,
            ),
            key: const Key('networthDeltaAmount'),
            style: tabularNumberStyle(
              Theme.of(context).textTheme.labelSmall!,
            ).copyWith(color: AppColors.iris),
          ),
        ],
      ),
    );
  }
}

class _AssetsCard extends StatelessWidget {
  const _AssetsCard({required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );

    return _FigureCard(
      label: l10n.networthAssetsLabel,
      amountKey: const Key('networthAssets'),
      amountMinor: summary.assetsMinor,
      currency: summary.currency,
      caption: summary.propertyValuesHeldFlat
          ? l10n.networthAssetsCaption(
              money(summary.accountsMinor),
              money(summary.propertiesMinor),
            )
          : l10n.networthAssetsCaptionNoProperty(money(summary.accountsMinor)),
      captionKey: const Key('networthAssetsCaption'),
    );
  }
}

class _LiabilitiesCard extends StatelessWidget {
  const _LiabilitiesCard({required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _FigureCard(
      label: l10n.networthLiabilitiesLabel,
      amountKey: const Key('networthLiabilities'),
      amountMinor: summary.mortgagesMinor,
      currency: summary.currency,
      caption: l10n.networthLiabilitiesCaption(summary.activeLoanCount),
      captionKey: const Key('networthLiabilitiesCaption'),
    );
  }
}

/// Actif and Passif share one silhouette: label, a 26 px neutral figure, and
/// the caption that says what it is made of.
class _FigureCard extends StatelessWidget {
  const _FigureCard({
    required this.label,
    required this.amountKey,
    required this.amountMinor,
    required this.currency,
    required this.caption,
    required this.captionKey,
  });

  final String label;
  final Key amountKey;
  final int amountMinor;
  final String currency;
  final String caption;
  final Key captionKey;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.statLabel),
          const SizedBox(height: AppSpacing.sm),
          AmountText(
            key: amountKey,
            amountMinor: amountMinor,
            currency: currency,
            colorize: false,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.displayMedium!.copyWith(fontSize: 26),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            caption,
            key: captionKey,
            style: tabularNumberStyle(
              AppTextStyles.helper,
            ).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Row 3, « Volontairement non compté »: what the synthèse leaves out on
/// purpose, one quiet line each. These exclusions are correct; left
/// unexplained, they would read as missing features.
class NetworthExclusionsCard extends StatelessWidget {
  const NetworthExclusionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget item(Key key, String title, String why) => Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(why, style: AppTextStyles.helper),
      ],
    );

    return AppCard(
      key: const Key('networthExclusions'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.networthExclusionsLabel.toUpperCase(),
            style: AppTextStyles.sectionLabel,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: item(
                  const Key('exclusionGoals'),
                  l10n.networthExclusionGoalsTitle,
                  l10n.networthExclusionGoalsBody,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: item(
                  const Key('exclusionSubscriptions'),
                  l10n.networthExclusionSubscriptionsTitle,
                  l10n.networthExclusionSubscriptionsBody,
                ),
              ),
              // The frame's grid is three columns; its third item left with
              // the tax feature, and the two remaining keep their width.
              const SizedBox(width: AppSpacing.lg),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}
