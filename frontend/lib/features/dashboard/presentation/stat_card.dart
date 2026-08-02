import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';

/// One stat card's MoM trend: a plain percentage-point delta plus whether an *increase* is the
/// good direction for this metric — income and net are better when they rise, expense is better
/// when it falls (see `docs/design/04-dashboard.md` §Notes and the card's acceptance criteria).
enum TrendDirection { upIsGood, upIsBad }

/// A headline figure with a label and a MoM trend row. Reused for income, expense, and net —
/// [SavingsRateCard] below shares the same trend semantics but a different, gradient-hero shape.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.amountMinor,
    required this.currency,
    required this.deltaPct,
    required this.direction,
    this.colorizeAmount = true,
  });

  final String label;
  final int amountMinor;
  final String currency;
  final double deltaPct;
  final TrendDirection direction;

  /// Off for [amountMinor] values that are neutral figures rather than a movement (e.g. net) —
  /// see the money color rule in the design-system skill.
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
          Text(label, style: textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          AmountText(
            amountMinor: amountMinor,
            currency: currency,
            showPositiveSign: colorizeAmount,
            colorize: colorizeAmount,
            style: textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendBadge(deltaPct: deltaPct, direction: direction),
        ],
      ),
    );
  }
}

/// The arrow + colored percentage row shared by every stat card's MoM trend.
class TrendBadge extends StatelessWidget {
  const TrendBadge({super.key, required this.deltaPct, required this.direction});

  final double deltaPct;
  final TrendDirection direction;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final up = deltaPct > 0;
    final good = deltaPct == 0
        ? null
        : (direction == TrendDirection.upIsGood ? up : !up);
    final color = switch (good) {
      null => AppColors.textSecondary,
      true => AppColors.positive,
      false => AppColors.negative,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          deltaPct == 0
              ? Icons.remove_rounded
              : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
          size: 12,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          formatDeltaPct(deltaPct, locale),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
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
String formatDeltaPct(double deltaPct, String locale) {
  final magnitude = NumberFormat('0.0', locale).format(deltaPct.abs());
  final sign = deltaPct > 0
      ? '+'
      : deltaPct < 0
      ? _minusSign
      : '';
  return '$sign$magnitude %';
}

/// Formats a plain percentage (not a delta) — used for the savings rate's headline value.
String formatPct(double pct, String locale) => '${NumberFormat('0.0', locale).format(pct)} %';

/// The single gradient-tinted hero card on the dashboard — savings rate is a first-class metric,
/// so it gets its own visual weight rather than sharing [StatCard]'s neutral surface.
class SavingsRateCard extends StatelessWidget {
  const SavingsRateCard({super.key, required this.label, required this.rate, required this.deltaPct});

  final String label;

  /// `0..1` ratio, as returned by the backend.
  final double rate;

  /// MoM change in [rate], already expressed in percentage points.
  final double deltaPct;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;

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
                  label,
                  style: textTheme.labelMedium?.copyWith(color: AppColors.irisInk.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  formatPct(rate * 100, locale),
                  style: textTheme.displayMedium?.copyWith(color: AppColors.irisInk),
                ),
                const SizedBox(height: AppSpacing.sm),
                TrendBadge(deltaPct: deltaPct, direction: TrendDirection.upIsGood),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _SavingsRateRing(rate: rate),
        ],
      ),
    );
  }
}

class _SavingsRateRing extends StatelessWidget {
  const _SavingsRateRing({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: rate.clamp(0.0, 1.0),
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            backgroundColor: AppColors.irisInk.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation(AppColors.irisInk),
          ),
        ],
      ),
    );
  }
}
