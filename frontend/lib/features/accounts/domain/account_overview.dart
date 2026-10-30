import 'package:flutter/foundation.dart';

import 'account.dart';

/// Everything the account detail panel shows about one account, in one read
/// (`GET /accounts/{id}/overview`): the account itself, how far back its
/// history goes, its month-end balances, the last twelve months' flows, and
/// the deferred-card links on either side of it.
@immutable
class AccountOverview {
  const AccountOverview({
    required this.account,
    required this.firstTransactionDate,
    required this.lastImportAt,
    required this.balanceHistory,
    required this.period,
    required this.linkedCards,
    required this.settlement,
  });

  final Account account;

  /// Booking date of the earliest transaction; `null` for an account with none.
  final DateTime? firstTransactionDate;

  /// When a statement was last imported into this account; `null` before any.
  final DateTime? lastImportAt;

  /// One balance per month, oldest first. The last point is this month's,
  /// which is today's balance.
  final List<BalancePoint> balanceHistory;

  final PeriodStats period;

  /// The deferred cards settled on this account. Empty for a card itself.
  final List<LinkedCard> linkedCards;

  /// A deferred card's own settlement picture; `null` for any other account.
  final CardSettlement? settlement;

  /// The chart needs two months to draw a line; before that it says when it
  /// will appear instead.
  bool get hasChartHistory => balanceHistory.length >= 2;
}

@immutable
class BalancePoint {
  const BalancePoint({required this.monthEnd, required this.balanceMinor});

  /// The last day of the month this balance closes — or today, for the
  /// current month.
  final DateTime monthEnd;
  final int balanceMinor;

  @override
  bool operator ==(Object other) =>
      other is BalancePoint &&
      other.monthEnd == monthEnd &&
      other.balanceMinor == balanceMinor;

  @override
  int get hashCode => Object.hash(monthEnd, balanceMinor);
}

/// The last twelve months of movement on the account. [changeMinor] is always
/// [inflowMinor] + [outflowMinor], so the three figures reconcile on screen.
@immutable
class PeriodStats {
  const PeriodStats({
    required this.since,
    required this.changeMinor,
    required this.inflowMinor,
    required this.outflowMinor,
    required this.consecutiveRisingMonths,
  });

  /// Where the window starts; `null` when the account has no history to
  /// measure from.
  final DateTime? since;
  final int changeMinor;

  /// Signed: zero or positive.
  final int inflowMinor;

  /// Signed: zero or negative.
  final int outflowMinor;

  /// How many month-ends in a row, counting back from now, closed above the
  /// one before.
  final int consecutiveRisingMonths;

  /// The encouraging line is only said when it is true, and one rise is not
  /// yet a streak worth naming.
  bool get isOnStreak => consecutiveRisingMonths >= 2;
}

/// A deferred card settled on the account being viewed.
@immutable
class LinkedCard {
  const LinkedCard({
    required this.accountId,
    required this.name,
    required this.institution,
    required this.cardLastDigits,
    required this.cycleMinor,
    required this.nextDebitDate,
    required this.hasRule,
  });

  final String accountId;
  final String name;
  final String institution;

  /// The card number's last four digits, when the bank id or the name gives
  /// them; the masked number is left out otherwise.
  final String? cardLastDigits;

  /// What the card has spent in its open cycle, signed (zero or negative).
  final int cycleMinor;

  /// When the open cycle is expected to be debited; `null` until the card has
  /// a settlement to project from.
  final DateTime? nextDebitDate;

  /// Without a settlement rule the card's debit counts as spending on top of
  /// its purchases — the row says so and offers the fix.
  final bool hasRule;
}

/// A deferred card's settlement: who pays it, by which rule, and what each
/// cycle came to.
@immutable
class CardSettlement {
  const CardSettlement({
    required this.payingAccountId,
    required this.cardLastDigits,
    required this.rule,
    required this.cycles,
    required this.currentCycleMinor,
    required this.nextDebitDate,
  });

  /// The account the card's debit is drawn from; `null` while unset.
  final String? payingAccountId;
  final String? cardLastDigits;
  final SettlementRuleSummary? rule;

  /// Oldest first. The last one is the open cycle when it is
  /// [SettlementCycle.inProgress].
  final List<SettlementCycle> cycles;

  /// The open cycle's total so far, signed (zero or negative) — the card's
  /// headline figure, since its balance resets every month.
  final int currentCycleMinor;
  final DateTime? nextDebitDate;

  /// The settled cycles only: the open one is still moving.
  List<SettlementCycle> get closedCycles =>
      cycles.where((cycle) => !cycle.inProgress).toList();

  /// The mean settled cycle, rounded to the cent; `null` before any settled.
  int? get averageClosedMinor {
    final closed = closedCycles;
    if (closed.isEmpty) return null;
    final total = closed.fold<int>(0, (sum, cycle) => sum + cycle.amountMinor);
    return (total / closed.length).round();
  }

  /// The settled cycle that charged the most (the most negative amount).
  SettlementCycle? get highestClosed {
    final closed = closedCycles;
    if (closed.isEmpty) return null;
    return closed.reduce((a, b) => b.amountMinor < a.amountMinor ? b : a);
  }

  SettlementCycle? get lastClosed {
    final closed = closedCycles;
    return closed.isEmpty ? null : closed.last;
  }

  /// How many settled cycles in a row, counting back from the latest, charged
  /// less than the one before — the card's own encouraging streak.
  int get consecutiveFallingCycles {
    final closed = closedCycles;
    var streak = 0;
    for (var i = closed.length - 1; i > 0; i--) {
      // Amounts are negative: charging less means a value closer to zero.
      if (closed[i].amountMinor > closed[i - 1].amountMinor) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

@immutable
class SettlementRuleSummary {
  const SettlementRuleSummary({
    required this.pattern,
    required this.enabled,
    required this.appliesFrom,
  });

  final String pattern;
  final bool enabled;
  final DateTime? appliesFrom;
}

@immutable
class SettlementCycle {
  const SettlementCycle({
    required this.settledOn,
    required this.amountMinor,
    required this.inProgress,
  });

  /// The debit's booking date; `null` for the open cycle.
  final DateTime? settledOn;

  /// Signed (zero or negative): what the cycle charged.
  final int amountMinor;
  final bool inProgress;
}

/// How much balance history the chart shows.
enum BalanceRange {
  sixMonths(6),
  twelveMonths(12),
  all(null);

  const BalanceRange(this.months);

  /// `null` for everything there is.
  final int? months;

  /// The trailing slice of [points] this range covers.
  List<T> slice<T>(List<T> points) {
    final count = months;
    if (count == null || points.length <= count) return points;
    return points.sublist(points.length - count);
  }
}
