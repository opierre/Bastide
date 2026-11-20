import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/networth_summary.dart';

/// Block 1 of the Synthèse (`15-synthese.md` §1), read as a sum: « Actif »
/// − « Passif » = « Patrimoine net ». Items bottom-aligned, 28 px apart.
///
/// Every figure is neutral (`00` §2.3): net worth keeps `text` even when
/// negative, with its U+2212. Its month change is a neutral status text, never
/// `positive` or `negative`, because a net-worth move is not income.
class NetworthEquation extends StatelessWidget {
  const NetworthEquation({super.key, required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );

    // Parts that are zero are left out of the caption.
    final assetsCaption = [
      if (summary.accountsMinor != 0)
        l10n.networthAssetsPartAccounts(money(summary.accountsMinor)),
      if (summary.propertiesMinor != 0)
        l10n.networthAssetsPartProperties(money(summary.propertiesMinor)),
    ].join(' · ');

    final operatorStyle = textTheme.displayMedium!.copyWith(
      color: context.colors.textTertiary,
    );

    // A [Wrap] rather than a [Row]: French figures run wide, and a narrow
    // window (sidebar expanded) drops the net worth to a second line instead
    // of overflowing.
    return Wrap(
      key: const Key('networthEquation'),
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppNetworth.equationGap,
      runSpacing: AppSpacing.md,
      children: [
        _EquationItem(
          label: l10n.networthAssetsLabel,
          figure: _Figure(
            key: const Key('networthAssets'),
            amountMinor: summary.assetsMinor,
            currency: summary.currency,
            style: textTheme.displayMedium!,
          ),
          caption: assetsCaption.isEmpty
              ? null
              : Text(
                  assetsCaption,
                  key: const Key('networthAssetsCaption'),
                  maxLines: 1,
                  style: _captionStyle(context),
                ),
        ),
        Text(l10n.networthEquationMinus, style: operatorStyle),
        _EquationItem(
          label: l10n.networthLiabilitiesLabel,
          figure: _Figure(
            key: const Key('networthLiabilities'),
            amountMinor: summary.mortgagesMinor,
            currency: summary.currency,
            style: textTheme.displayMedium!,
          ),
          caption: Text(
            l10n.networthLiabilitiesCaption(summary.activeLoanCount),
            key: const Key('networthLiabilitiesCaption'),
            maxLines: 1,
            style: _captionStyle(context),
          ),
        ),
        Text(l10n.networthEquationEquals, style: operatorStyle),
        _EquationItem(
          label: l10n.networthNetWorthLabel,
          gap: AppSpacing.xs,
          figure: _Figure(
            key: const Key('networthValue'),
            amountMinor: summary.netWorthMinor,
            currency: summary.currency,
            style: textTheme.displayLarge!,
          ),
          caption: _delta(l10n, locale),
        ),
      ],
    );
  }

  /// « +1 977,78 € depuis avril »: this month against the one before, with
  /// `trending-up`, `trending-down`, or `minus` when it did not move.
  Widget? _delta(AppLocalizations l10n, String locale) {
    final delta = summary.monthDeltaMinor;
    final series = summary.series;
    if (delta == null || series.length < 2) return null;
    final since = DateFormat.MMMM(
      locale,
    ).format(series[series.length - 2].month);
    return StatusText(
      key: const Key('networthDelta'),
      icon: switch (delta) {
        > 0 => LucideIcons300.trendingUp,
        < 0 => LucideIcons300.trendingDown,
        _ => LucideIcons300.minus,
      },
      label: l10n.networthDeltaCaption(
        formatAmount(
          amountMinor: delta,
          currency: summary.currency,
          locale: locale,
          showPositiveSign: true,
        ),
        since,
      ),
    );
  }

  static TextStyle _captionStyle(BuildContext context) => tabularNumberStyle(
    Theme.of(context).textTheme.bodySmall!,
  ).copyWith(color: context.colors.textTertiary);
}

/// A neutral figure in the type it is given.
class _Figure extends StatelessWidget {
  const _Figure({
    super.key,
    required this.amountMinor,
    required this.currency,
    required this.style,
  });

  final int amountMinor;
  final String currency;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => AmountText(
    amountMinor: amountMinor,
    currency: currency,
    colorize: false,
    maxLines: 1,
    style: style.copyWith(color: context.colors.text),
  );
}

/// One term of the equation: label 12 `textSecondary`, the figure, then a
/// caption, [gap] apart (6, or 4 under the lead figure).
class _EquationItem extends StatelessWidget {
  const _EquationItem({
    required this.label,
    required this.figure,
    this.caption,
    this.gap = AppSpacing.xsPlus,
  });

  final String label;
  final Widget figure;
  final Widget? caption;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, style: context.textStyles.statLabel),
        SizedBox(height: gap),
        figure,
        if (caption case final caption?) ...[SizedBox(height: gap), caption],
      ],
    );
  }
}
