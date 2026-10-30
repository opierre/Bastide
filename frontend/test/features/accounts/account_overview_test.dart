import 'package:bastide/features/accounts/data/accounts_repository.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/domain/account_overview.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_overview_fixtures.dart';

void main() {
  group('parseOverview', () {
    test('maps a checking account with its linked cards', () {
      final overview = AccountsRepository.parseOverview(checkingOverviewJson());

      expect(overview.account.id, 'acc-1');
      expect(overview.account.type, AccountType.checking);
      expect(overview.firstTransactionDate, DateTime(2025, 1, 3));
      expect(overview.lastImportAt, DateTime.utc(2026, 10, 28, 9, 30));
      expect(overview.balanceHistory, hasLength(3));
      expect(
        overview.balanceHistory.last,
        BalancePoint(monthEnd: DateTime(2026, 10, 30), balanceMinor: 348612),
      );
      expect(overview.period.changeMinor, 124050);
      expect(overview.period.inflowMinor, 2841000);
      expect(overview.period.outflowMinor, -2716950);
      expect(overview.period.consecutiveRisingMonths, 4);
      expect(overview.period.since, DateTime(2025, 10, 31));
      expect(overview.settlement, isNull);

      final card = overview.linkedCards.first;
      expect(card.accountId, 'card-1');
      expect(card.cardLastDigits, '4821');
      expect(card.cycleMinor, -61240);
      expect(card.nextDebitDate, DateTime(2026, 11, 5));
      expect(card.hasRule, isTrue);
      final second = overview.linkedCards[1];
      expect(second.cardLastDigits, isNull);
      expect(second.nextDebitDate, isNull);
      expect(second.hasRule, isFalse);
    });

    test('maps a deferred card with its settlement', () {
      final overview = AccountsRepository.parseOverview(cardOverviewJson());
      final settlement = overview.settlement!;

      expect(overview.linkedCards, isEmpty);
      expect(settlement.payingAccountId, 'acc-1');
      expect(settlement.cardLastDigits, '4821');
      expect(settlement.rule!.pattern, 'CARTE X4821');
      expect(settlement.rule!.appliesFrom, DateTime(2025, 2, 5));
      expect(settlement.cycles, hasLength(4));
      expect(settlement.cycles.last.inProgress, isTrue);
      expect(settlement.cycles.last.settledOn, isNull);
      expect(settlement.currentCycleMinor, -61240);
      expect(settlement.nextDebitDate, DateTime(2026, 11, 5));
    });

    test('maps an account with no history to nulls, not zeros', () {
      final overview = AccountsRepository.parseOverview(freshOverviewJson());

      expect(overview.firstTransactionDate, isNull);
      expect(overview.lastImportAt, isNull);
      expect(overview.period.since, isNull);
      expect(overview.hasChartHistory, isFalse);
    });
  });

  group('domain', () {
    test('a balance range keeps the trailing months', () {
      final points = List.generate(20, (i) => i);

      expect(BalanceRange.sixMonths.slice(points), [14, 15, 16, 17, 18, 19]);
      expect(BalanceRange.twelveMonths.slice(points), hasLength(12));
      expect(BalanceRange.all.slice(points), hasLength(20));
      expect(BalanceRange.twelveMonths.slice([1, 2]), [1, 2]);
    });

    test('a streak needs two rises in a row', () {
      PeriodStats period(int months) => PeriodStats(
        since: null,
        changeMinor: 0,
        inflowMinor: 0,
        outflowMinor: 0,
        consecutiveRisingMonths: months,
      );

      expect(period(1).isOnStreak, isFalse);
      expect(period(2).isOnStreak, isTrue);
    });

    test('card cycle figures read the settled cycles only', () {
      final settlement = AccountsRepository.parseOverview(
        cardOverviewJson(),
      ).settlement!;

      // -93175, -88420, -80360 settled; -61240 open.
      expect(settlement.closedCycles, hasLength(3));
      expect(settlement.averageClosedMinor, -87318);
      expect(settlement.highestClosed!.amountMinor, -93175);
      expect(settlement.lastClosed!.amountMinor, -80360);
      expect(settlement.consecutiveFallingCycles, 2);
    });

    test('cycle figures are absent before any settled cycle', () {
      const settlement = CardSettlement(
        payingAccountId: null,
        cardLastDigits: null,
        rule: null,
        cycles: [
          SettlementCycle(
            settledOn: null,
            amountMinor: -1000,
            inProgress: true,
          ),
        ],
        currentCycleMinor: -1000,
        nextDebitDate: null,
      );

      expect(settlement.averageClosedMinor, isNull);
      expect(settlement.highestClosed, isNull);
      expect(settlement.lastClosed, isNull);
      expect(settlement.consecutiveFallingCycles, 0);
    });
  });
}
