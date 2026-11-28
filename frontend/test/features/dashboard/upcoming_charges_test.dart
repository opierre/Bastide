import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/logos/logo_ref.dart';
import 'package:bastide/features/dashboard/application/upcoming_charges_provider.dart';
import 'package:bastide/features/dashboard/domain/upcoming_charges.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

UpcomingDue _due(String id, int day) => UpcomingDue(
  seriesId: id,
  label: id,
  amountMinor: -1000,
  logo: null,
  dueOn: DateTime(2026, 5, day),
);

UpcomingMissed _missed(String id, int day) => UpcomingMissed(
  seriesId: id,
  label: id,
  amountMinor: -2000,
  logo: null,
  expectedOn: DateTime(2026, 5, day),
);

UpcomingCharges _charges(List<UpcomingDue> due, List<UpcomingMissed> missed) =>
    UpcomingCharges(
      through: DateTime(2026, 5, 31),
      totalMinor: due.fold(0, (sum, row) => sum + row.amountMinor),
      due: due,
      missed: missed,
      currency: 'EUR',
    );

void main() {
  group('rows', () {
    test('due charges by date come first, missed ones after them', () {
      final rows = _charges(
        [_due('a', 15), _due('b', 22)],
        [_missed('m', 5)],
      ).rows;

      expect([for (final row in rows) row.seriesId], ['a', 'b', 'm']);
    });

    test('past four rows the latest due charges are left out first', () {
      final rows = _charges(
        [_due('a', 15), _due('b', 18), _due('c', 22), _due('d', 28)],
        [_missed('m1', 3), _missed('m2', 5)],
      ).rows;

      expect([for (final row in rows) row.seriesId], ['a', 'b', 'm1', 'm2']);
    });

    test('nothing due and nothing missed is empty', () {
      expect(_charges(const [], const []).isEmpty, isTrue);
      expect(_charges(const [], [_missed('m', 5)]).isEmpty, isFalse);
    });
  });

  test('the provider maps /recurring/upcoming to the domain', () async {
    final apiClient = MockApiClient();
    when(() => apiClient.get('/recurring/upcoming')).thenAnswer(
      (_) async => {
        'through': '2026-05-31',
        'total_minor': -3348,
        'charges': [
          {
            'series_id': 's1',
            'label': 'Streamco',
            'amount_minor': -1549,
            'due_on': '2026-05-15',
            'price_increase_minor': -200,
            'logo_rule_id': 'r1',
            'logo_updated_at': '2026-04-01T10:00:00Z',
          },
          {
            'series_id': 's2',
            'label': 'Musiq Famille',
            'amount_minor': -1799,
            'due_on': '2026-05-22',
            'price_increase_minor': null,
            'logo_rule_id': null,
            'logo_updated_at': null,
          },
        ],
        'missed': [
          {
            'series_id': 's3',
            'label': 'Forme Club',
            'amount_minor': -2999,
            'expected_on': '2026-05-05',
            'days_late': 9,
            'logo_rule_id': null,
            'logo_updated_at': null,
          },
        ],
        'currency': 'EUR',
      },
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(upcomingChargesProvider, (_, _) {});
    addTearDown(subscription.close);

    final upcoming = await container.read(upcomingChargesProvider.future);

    expect(upcoming.through, DateTime(2026, 5, 31));
    expect(upcoming.totalMinor, -3348);
    expect(upcoming.currency, 'EUR');
    final rise = upcoming.due.first;
    expect(rise.seriesId, 's1');
    expect(rise.amountMinor, -1549);
    expect(rise.dueOn, DateTime(2026, 5, 15));
    expect(rise.priceIncreaseMinor, -200);
    expect(
      rise.logo,
      LogoRef(ruleId: 'r1', updatedAt: DateTime.utc(2026, 4, 1, 10)),
    );
    expect(upcoming.due.last.priceIncreaseMinor, isNull);
    expect(upcoming.due.last.logo, isNull);
    final missed = upcoming.missed.single;
    expect(missed.label, 'Forme Club');
    expect(missed.amountMinor, -2999);
    expect(missed.expectedOn, DateTime(2026, 5, 5));
  });
}
