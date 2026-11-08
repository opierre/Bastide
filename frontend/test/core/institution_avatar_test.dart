import 'dart:typed_data';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/logos/logo_ref.dart';
import 'package:bastide/core/widgets/institution_avatar.dart';
import 'package:bastide/core/widgets/monogram_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

// A 1×1 transparent PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final _logo = LogoRef(ruleId: 'r1', updatedAt: DateTime.utc(2026, 5, 14));

void main() {
  late _MockApiClient api;

  setUp(() => api = _MockApiClient());

  Future<void> pump(WidgetTester tester, {LogoRef? logo}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: InstitutionAvatar(name: 'Streamflix', logo: logo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the rule logo when the row has one', (tester) async {
    when(
      () => api.getBytes('/rules/r1/logo'),
    ).thenAnswer((_) async => ApiBytesResponse(bytes: _png, headers: {}));

    await pump(tester, logo: _logo);

    expect(find.byKey(const Key('institutionAvatarLogo')), findsOneWidget);
    expect(find.byType(MonogramAvatar), findsNothing);
  });

  testWidgets('shows the monogram when the row has no logo', (tester) async {
    await pump(tester);

    expect(find.byType(MonogramAvatar), findsOneWidget);
    expect(find.byKey(const Key('institutionAvatarLogo')), findsNothing);
    verifyNever(() => api.getBytes(any()));
  });

  testWidgets('falls back to the monogram when the logo fails to load', (
    tester,
  ) async {
    when(() => api.getBytes('/rules/r1/logo')).thenThrow(
      const ApiFailure(code: 'RULE_LOGO_NOT_FOUND', message: 'No logo.'),
    );

    await pump(tester, logo: _logo);

    expect(find.byType(MonogramAvatar), findsOneWidget);
    expect(find.byKey(const Key('institutionAvatarLogo')), findsNothing);
  });

  testWidgets('falls back to the monogram when the logo does not decode', (
    tester,
  ) async {
    when(() => api.getBytes('/rules/r1/logo')).thenAnswer(
      (_) async =>
          ApiBytesResponse(bytes: Uint8List.fromList([1, 2, 3]), headers: {}),
    );

    await pump(tester, logo: _logo);
    // Decoding happens off the frame: let it fail, then rebuild.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byType(MonogramAvatar), findsOneWidget);
  });

  testWidgets('a replaced logo is fetched again under its new version', (
    tester,
  ) async {
    when(
      () => api.getBytes('/rules/r1/logo'),
    ).thenAnswer((_) async => ApiBytesResponse(bytes: _png, headers: {}));

    await pump(tester, logo: _logo);
    await pump(
      tester,
      logo: LogoRef(ruleId: 'r1', updatedAt: DateTime.utc(2026, 5, 15)),
    );

    verify(() => api.getBytes('/rules/r1/logo')).called(2);
  });
}
