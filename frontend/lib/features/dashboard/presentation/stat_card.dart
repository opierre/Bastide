import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';

/// A headline figure with a label, a MoM trend pill, and a caption naming what the trend is
/// measured against. Reused for income, expense, and net — [SavingsRateCard] below shares the
/// same trend semantics but a different, gradient-hero shape.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.amountMinor,
    required this.currency,
    required this.deltaPct,
    required this.caption,
    this.colorizeAmount = true,
    this.invertTrendColor = false,
  });

  final String label;
  final int amountMinor;
  final String currency;
  final double deltaPct;

  /// On for a metric where *rising* is the bad outcome — the expense card. See [TrendRow].
  final bool invertTrendColor;

  /// The 11.5px line beside the trend pill — « vs avril », « revenus − dépenses ».
  final String caption;

  /// Off for [amountMinor] values that are neutral figures rather than a movement (e.g. net) —
  /// see the money color rule in the design-system skill. The *sign* is not affected: every
  /// figure on this row is signed, colorized or not.
  final bool colorizeAmount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.statLabel),
          const SizedBox(height: AppSpacing.sm),
          AmountText(
            amountMinor: amountMinor,
            currency: currency,
            // Always signed, even when neutral: the spec's net card reads `+635,65 €` in
            // primary text, so the sign carries the direction that the color no longer does.
            showPositiveSign: true,
            colorize: colorizeAmount,
            style: textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendRow(
            deltaPct: deltaPct,
            caption: caption,
            invertColor: invertTrendColor,
          ),
        ],
      ),
    );
  }
}

/// The trend pill and its caption, shared by every stat card.
///
/// The pill is 22px with the semantic hue at 12% and a triangle rotated 0/180. Color follows
/// whether the movement is *good news*, not the raw sign: rising income is green, and rising
/// expenses are red (see [invertColor]). Direction is carried by the glyph's rotation and the
/// explicit sign as well as by the fill, so it never rests on color alone — which is what lets
/// the hue mean "good/bad" rather than "up/down".
class TrendRow extends StatelessWidget {
  const TrendRow({
    super.key,
    required this.deltaPct,
    required this.caption,
    this.label,
    this.onGradient = false,
    this.invertColor = false,
  });

  final double deltaPct;
  final String caption;

  /// Swaps the pill's two hues, for a metric where a rise is the bad outcome. Only the expense
  /// card sets it: spending less month over month is a win, so its « −4,6 % » reads green while
  /// the triangle still points down.
  final bool invertColor;

  /// Overrides the pill's text — the savings card measures its change in percentage *points*
  /// rather than percent, so it supplies its own already-formatted string.
  final String? label;

  /// Ink treatment for the gradient savings card. Semantic green on the iris gradient lands
  /// around 2:1 contrast, well under AA, so on that surface the pill takes the card's own ink
  /// and lets the sign and the triangle carry the direction.
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final up = deltaPct > 0;
    final riseColor = invertColor ? AppColors.negative : AppColors.positive;
    final fallColor = invertColor ? AppColors.positive : AppColors.negative;
    final color = onGradient
        ? AppColors.irisInk
        : switch (deltaPct) {
            > 0 => riseColor,
            < 0 => fallColor,
            // A flat month is neither: it takes the secondary tone and a dash rather than
            // borrowing one of the two money colors.
            _ => AppColors.textSecondary,
          };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // One triangle glyph, rotated a half turn for a fall — the spec draws a single
              // mark at 0/180 rather than two different arrows.
              if (deltaPct != 0)
                Transform.rotate(
                  angle: up ? 0 : math.pi,
                  child: Icon(Icons.arrow_drop_up, size: 14, color: color),
                )
              else
                Icon(Icons.remove_rounded, size: 11, color: color),
              const SizedBox(width: 1),
              Text(
                label ?? formatDeltaPct(deltaPct, locale),
                style: tabularNumberStyle(
                  textTheme.labelSmall!,
                ).copyWith(color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            caption,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w400,
              color: onGradient
                  ? AppColors.irisInk.withValues(alpha: 0.75)
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// U+2212 minus sign, matching [AmountText]'s convention so a negative percentage doesn't fall
/// back to the narrower ASCII hyphen `intl` emits.
const _minusSign = '−';

/// Formats a MoM percentage-point delta with an explicit `+`/`−` sign — the sign is what carries
/// direction alongside color, per the design-system's never-color-alone rule.
String formatDeltaPct(double deltaPct, String locale) =>
    '${formatSignedMagnitude(deltaPct, locale)} %';

/// The signed number alone, without a unit. The savings card appends « pt » instead of « % ».
String formatSignedMagnitude(double value, String locale) {
  final magnitude = NumberFormat('0.0', locale).format(value.abs());
  final sign = value > 0
      ? '+'
      : value < 0
      ? _minusSign
      : '';
  return '$sign$magnitude';
}

/// Formats a plain percentage (not a delta) — used for the savings rate's ring value and for
/// the goal in its caption.
String formatPct(double pct, String locale) => '${NumberFormat('0.0', locale).format(pct)} %';

/// Formats a whole percentage, for the goal figure — « Objectif : 20 % », not « 20,0 % ».
String formatWholePct(double pct, String locale) =>
    '${NumberFormat('0', locale).format(pct)} %';

/// The single gradient-tinted hero card on the dashboard — savings rate is a first-class metric,
/// so it gets its own visual weight rather than sharing [StatCard]'s neutral surface.
///
/// The rate lives *inside* the ring rather than in the left column: the ring is the value's
/// display, and repeating the figure beside it would read as two numbers.
class SavingsRateCard extends StatelessWidget {
  const SavingsRateCard({
    super.key,
    required this.label,
    required this.rate,
    required this.deltaPct,
    required this.deltaLabel,
    required this.caption,
  });

  final String label;

  /// `0..1` ratio, as returned by the backend.
  final double rate;

  /// MoM change in [rate], already expressed in percentage points. Carries the *direction*
  /// (which picks the triangle's rotation); [deltaLabel] carries the text.
  final double deltaPct;

  /// « +1,9 pt ». A change in a rate is measured in percentage points rather than percent, so
  /// this card's pill is localized by the caller instead of using [formatDeltaPct].
  final String deltaLabel;

  /// « Objectif : 20 % · atteint », resolved by the caller from the summary's goal state.
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      gradient: AppColors.irisGradient,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.statLabel.copyWith(
                    color: AppColors.irisInk.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TrendRow(
                  deltaPct: deltaPct,
                  caption: caption,
                  label: deltaLabel,
                  onGradient: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SavingsRateRing(rate: rate),
        ],
      ),
    );
  }
}

/// The 96px ring: r 40, stroke 10, round cap, with the rate centred inside it.
///
/// The indicator is sized to 90 inside the 96 slot because Flutter measures the arc's radius
/// from the box edge inwards by half the stroke — `(90 − 10) / 2` is the spec's r 40, where a
/// 96px indicator would draw r 43.
class SavingsRateRing extends StatelessWidget {
  const SavingsRateRing({super.key, required this.rate});

  final double rate;

  static const _size = 96.0;
  static const _stroke = 10.0;
  static const _radius = 40.0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: _radius * 2 + _stroke,
            height: _radius * 2 + _stroke,
            child: CircularProgressIndicator(
              value: rate.clamp(0.0, 1.0),
              strokeWidth: _stroke,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.irisInk.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.irisInk),
            ),
          ),
          Text(
            formatPct(rate * 100, locale),
            key: const Key('dashboardSavingsRateValue'),
            style: tabularNumberStyle(
              Theme.of(context).textTheme.headlineSmall!,
            ).copyWith(color: AppColors.irisInk),
          ),
        ],
      ),
    );
  }
}
