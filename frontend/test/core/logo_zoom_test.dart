import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/logos/logo_ref.dart';
import 'package:bastide/core/widgets/institution_avatar.dart';
import 'package:bastide/core/widgets/logo_zoom.dart';
import 'package:bastide/features/rules/domain/rule_pack.dart';
import 'package:bastide/features/rules/presentation/rule_pack_logo_chip.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

// A 1×1 transparent PNG — an invented picture, not anyone's logo.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

final _logo = LogoRef(ruleId: 'r1', updatedAt: DateTime.utc(2026, 5, 14));

const _target = Key('logoZoomTarget');
const _dialog = Key('logoZoomDialog');

void main() {
  late _MockApiClient api;

  setUp(() {
    api = _MockApiClient();
    when(
      () => api.getBytes('/rules/r1/logo'),
    ).thenAnswer((_) async => ApiBytesResponse(bytes: _png, headers: {}));
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('fr'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('InstitutionAvatar', () {
    testWidgets('clicking a zoomable logo opens it larger; Escape closes it', (
      tester,
    ) async {
      await pump(
        tester,
        InstitutionAvatar(name: 'Streamflix', logo: _logo, zoomable: true),
      );

      await tester.tap(find.byKey(_target));
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsOneWidget);
      expect(
        tester.getSize(find.byType(Image).last),
        const Size.square(LogoZoomDialog.size),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsNothing);
    });

    testWidgets('a click outside the enlarged logo closes it', (tester) async {
      await pump(
        tester,
        InstitutionAvatar(name: 'Streamflix', logo: _logo, zoomable: true),
      );
      await tester.tap(find.byKey(_target));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsNothing);
    });

    testWidgets('the monogram fallback is not clickable', (tester) async {
      await pump(
        tester,
        const InstitutionAvatar(name: 'Streamflix', zoomable: true),
      );

      expect(find.byKey(_target), findsNothing);
    });

    testWidgets('a logo is not clickable unless asked to be', (tester) async {
      await pump(tester, InstitutionAvatar(name: 'Streamflix', logo: _logo));

      expect(find.byKey(const Key('institutionAvatarLogo')), findsOneWidget);
      expect(find.byKey(_target), findsNothing);
    });

    for (final (locale, label) in [
      (const Locale('fr'), 'Afficher le logo en grand'),
      (const Locale('en'), 'Show the logo larger'),
    ]) {
      testWidgets('labels the clickable logo for screen readers ($locale)', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          InstitutionAvatar(name: 'Streamflix', logo: _logo, zoomable: true),
          locale: locale,
        );

        expect(
          tester.getSemantics(find.byKey(_target)),
          isSemantics(label: label, isButton: true, hasTapAction: true),
        );
        semantics.dispose();
      });
    }
  });

  group('RulePackLogoChip', () {
    testWidgets('clicking an embedded logo opens it larger', (tester) async {
      await pump(
        tester,
        RulePackLogoChip(
          entry: RulePackEntry.fromJson(const {
            'field': 'merchant',
            'type': 'contains',
            'pattern': 'CAFE DU PORT',
            'category_key': 'category.food.restaurants',
            'logo': {'data': _pngBase64},
          }),
        ),
      );

      await tester.tap(find.byKey(_target));
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsNothing);
    });

    testWidgets('a rule without an embedded logo is not clickable', (
      tester,
    ) async {
      await pump(
        tester,
        const RulePackLogoChip(
          entry: RulePackEntry(
            field: 'merchant',
            type: 'contains',
            pattern: 'BOULANGERIE MARCEL',
            categoryKey: 'category.food.groceries',
          ),
        ),
      );

      expect(find.byKey(_target), findsNothing);
    });
  });
}
