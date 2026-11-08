import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/logos/logo_ref.dart';
import 'package:bastide/core/pictures/pictures.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/rules/application/rule_logo_controller.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockImaging extends Mock implements PictureImaging {}

class _FakeImage extends Fake implements ui.Image {}

const _stamp = '2026-05-14T10:00:00Z';

Map<String, dynamic> _logoFields(bool on) => {
  'logo_rule_id': on ? 'r1' : null,
  'logo_updated_at': on ? _stamp : null,
};

Map<String, dynamic> _ruleJson({bool logo = false}) => {
  'id': 'r1',
  'priority': 1,
  'match_field': 'description_clean',
  'match_type': 'contains',
  'pattern': 'STREAMFLIX',
  'category_id': 'leisure',
  'enabled': true,
  'logo_updated_at': logo ? _stamp : null,
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _transactionJson(bool logo) => {
  'id': 't1',
  'account_id': 'a1',
  'booked_date': '2026-05-05',
  'value_date': null,
  'amount_minor': -1399,
  'currency': 'EUR',
  'description_raw': 'PRLV STREAMFLIX',
  'description_clean': 'STREAMFLIX',
  'merchant': null,
  'category': null,
  'categorization_source': 'rule',
  'categorization_confidence': null,
  'needs_review': false,
  'fitid': null,
  'dedup_hash': 'hash-1',
  'created_at': '2026-05-05T00:00:00Z',
  'updated_at': '2026-05-05T00:00:00Z',
  ..._logoFields(logo),
};

Map<String, dynamic> _seriesJson(bool logo) => {
  'id': 's1',
  'account_id': 'a1',
  'label': 'Streamflix',
  'category_id': null,
  'cadence': 'monthly',
  'median_interval_days': 30,
  'expected_amount_minor': -1399,
  'currency': 'EUR',
  'first_seen_date': '2026-01-05',
  'last_seen_date': '2026-05-05',
  'next_expected_date': '2026-06-05',
  'occurrence_count': 5,
  'status': 'detected',
  'is_manual': false,
  'archived': false,
  'price_change_minor': null,
  'price_changed_at': null,
  'created_at': '2026-01-05T00:00:00',
  'updated_at': '2026-05-05T00:00:00',
  ..._logoFields(logo),
};

final _summaryJson = {
  'monthly_total_minor': -1399,
  'active_count': 1,
  'cancelled_count': 0,
  'cadence_counts': {
    'weekly': 0,
    'monthly': 1,
    'quarterly': 0,
    'yearly': 0,
    'irregular': 0,
  },
  'next_charge': null,
  'price_increases': <Map<String, dynamic>>[],
  'missed': <Map<String, dynamic>>[],
  'currency': 'EUR',
};

final _logo = LogoRef(ruleId: 'r1', updatedAt: DateTime.parse(_stamp));

void main() {
  late _MockApiClient api;
  late _MockImaging imaging;
  late ProviderContainer container;
  // What the backend resolves for the rows: on once the rule has a logo.
  var logoOnServer = false;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(_FakeImage());
    registerFallbackValue(Rect.zero);
  });

  setUp(() {
    api = _MockApiClient();
    imaging = _MockImaging();
    logoOnServer = false;
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        pictureImagingProvider.overrideWithValue(imaging),
      ],
    );
    addTearDown(container.dispose);

    when(
      () => api.get('/rules'),
    ).thenAnswer((_) async => [_ruleJson(logo: logoOnServer)]);
    when(() => api.get('/transactions', query: any(named: 'query'))).thenAnswer(
      (_) async => {
        'items': [_transactionJson(logoOnServer)],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
    );
    when(
      () => api.get('/recurring', query: any(named: 'query')),
    ).thenAnswer((_) async => [_seriesJson(logoOnServer)]);
    when(
      () => api.get('/recurring', query: {'archived': 'true'}),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(
      () => api.get('/recurring/summary'),
    ).thenAnswer((_) async => _summaryJson);
    when(
      () => api.get('/recurring/merge-suggestions'),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(
      () => imaging.cropToPng(any(), any()),
    ).thenAnswer((_) async => Uint8List.fromList([9, 9, 9]));
  });

  Future<void> loadViews() async {
    await container.read(rulesControllerProvider.future);
    await container.read(transactionsControllerProvider.future);
    await container.read(subscriptionsControllerProvider.future);
  }

  LogoRef? transactionLogo() =>
      container.read(transactionsControllerProvider).value!.items.single.logo;
  LogoRef? seriesLogo() =>
      container.read(subscriptionsControllerProvider).value!.series.single.logo;

  test('the wire reference parses, and none means the monogram', () {
    expect(LogoRef.fromJson(_logoFields(true)), _logo);
    expect(LogoRef.fromJson(_logoFields(false)), isNull);
    expect(Rule.fromJson(_ruleJson(logo: true)).logo, _logo);
    expect(Rule.fromJson(_ruleJson()).logo, isNull);
  });

  test(
    'uploading a logo updates the matching rows in Transactions and Abonnements',
    () async {
      when(
        () => api.putMultipart(
          '/rules/r1/logo',
          fileField: 'file',
          fileName: 'logo.png',
          fileBytes: any(named: 'fileBytes'),
        ),
      ).thenAnswer((_) async {
        logoOnServer = true;
        return _ruleJson(logo: true);
      });
      await loadViews();
      expect(transactionLogo(), isNull);
      expect(seriesLogo(), isNull);

      final saved = await container
          .read(ruleLogoControllerProvider.notifier)
          .upload('r1', _FakeImage(), const Rect.fromLTWH(0, 0, 10, 10));

      expect(saved, isTrue);
      expect(container.read(rulesControllerProvider).value!.single.logo, _logo);
      expect(transactionLogo(), _logo);
      expect(seriesLogo(), _logo);
    },
  );

  test('removing the logo brings the monogram back on those rows', () async {
    logoOnServer = true;
    when(() => api.delete('/rules/r1/logo')).thenAnswer((_) async {
      logoOnServer = false;
      return _ruleJson();
    });
    await loadViews();
    expect(transactionLogo(), _logo);

    await container.read(ruleLogoControllerProvider.notifier).remove('r1');

    expect(container.read(rulesControllerProvider).value!.single.logo, isNull);
    expect(transactionLogo(), isNull);
    expect(seriesLogo(), isNull);
  });

  test('a refused upload reports why and changes nothing', () async {
    when(
      () => api.putMultipart(
        '/rules/r1/logo',
        fileField: 'file',
        fileName: 'logo.png',
        fileBytes: any(named: 'fileBytes'),
      ),
    ).thenThrow(
      const ApiFailure(
        code: 'RULE_LOGO_INVALID_IMAGE',
        message: 'Not a picture.',
      ),
    );
    await loadViews();

    final saved = await container
        .read(ruleLogoControllerProvider.notifier)
        .upload('r1', _FakeImage(), const Rect.fromLTWH(0, 0, 10, 10));

    expect(saved, isFalse);
    expect(
      container.read(ruleLogoControllerProvider).failure,
      PictureUploadFailure.invalidType,
    );
    expect(container.read(rulesControllerProvider).value!.single.logo, isNull);
  });

  test('a file over the size cap is refused before it is read', () async {
    final files = _MockFiles();
    var read = false;
    when(files.pick).thenAnswer(
      (_) async => (
        length: maxPictureUploadBytes + 1,
        read: () async {
          read = true;
          return Uint8List(0);
        },
      ),
    );
    final scoped = ProviderContainer(
      overrides: [pictureFilesProvider.overrideWithValue(files)],
    );
    addTearDown(scoped.dispose);
    final sub = scoped.listen(ruleLogoControllerProvider, (_, _) {});
    addTearDown(sub.close);

    final image = await scoped.read(ruleLogoControllerProvider.notifier).pick();

    expect(image, isNull);
    expect(read, isFalse);
    expect(
      scoped.read(ruleLogoControllerProvider).failure,
      PictureUploadFailure.tooLarge,
    );
  });
}

class _MockFiles extends Mock implements PictureFiles {}
