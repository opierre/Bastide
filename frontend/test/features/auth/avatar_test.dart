import 'dart:typed_data';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/monogram_avatar.dart';
import 'package:bastide/core/widgets/user_avatar.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/domain/avatar_choice.dart';
import 'package:bastide/features/auth/presentation/avatar_card.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_auth_controller.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'ada',
  locale: 'fr',
  currency: 'EUR',
);

Map<String, dynamic> _userJson(String avatar) => {
  'id': 'u1',
  'email': 'ada@example.com',
  'display_name': 'ada',
  'locale': 'fr',
  'currency': 'EUR',
  'avatar': avatar,
  'created_at': '2026-10-09T00:00:00Z',
};

// A 1×1 transparent PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _bare(Widget child) => MaterialApp(
  theme: appDarkTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AvatarChoice.fromWire', () {
    test('reads each kind', () {
      expect(AvatarChoice.fromWire('monogram'), const MonogramChoice());
      expect(
        AvatarChoice.fromWire('preset:teal'),
        const PresetChoice(AvatarPreset.teal),
      );
      expect(AvatarChoice.fromWire('image'), const PictureChoice());
    });

    test('falls back to the monogram on anything unknown', () {
      for (final wire in [null, '', 'preset:', 'preset:plaid', 'emoji']) {
        expect(AvatarChoice.fromWire(wire), const MonogramChoice());
      }
    });

    test('round-trips every preset through its wire key', () {
      for (final preset in AvatarPreset.values) {
        final choice = PresetChoice(preset);
        expect(AvatarChoice.fromWire(choice.wire), choice);
      }
    });
  });

  group('UserAvatar', () {
    testWidgets('the monogram renders the initials', (tester) async {
      await tester.pumpWidget(
        _bare(const UserAvatar(name: 'ada', avatar: MonogramChoice())),
      );

      expect(find.byType(UserMonogram), findsOneWidget);
      expect(find.text('AD'), findsOneWidget);
    });

    testWidgets('a preset renders the initials on its plate', (tester) async {
      await tester.pumpWidget(
        _bare(
          const UserAvatar(
            name: 'ada',
            avatar: PresetChoice(AvatarPreset.pink),
          ),
        ),
      );

      expect(find.byKey(const Key('userAvatarPreset')), findsOneWidget);
      expect(find.byType(UserMonogram), findsNothing);
      expect(find.text('AD'), findsOneWidget);
    });

    testWidgets('a picture renders its bytes', (tester) async {
      await tester.pumpWidget(
        _bare(
          UserAvatar(name: 'ada', avatar: const PictureChoice(), image: _png),
        ),
      );

      expect(find.byKey(const Key('userAvatarPicture')), findsOneWidget);
      expect(find.byType(UserMonogram), findsNothing);
    });

    testWidgets('a picture with no bytes falls back to the monogram', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bare(const UserAvatar(name: 'ada', avatar: PictureChoice())),
      );

      expect(find.byType(UserMonogram), findsOneWidget);
    });

    testWidgets('bytes that are not a picture fall back to the monogram', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bare(
          UserAvatar(
            name: 'ada',
            avatar: const PictureChoice(),
            image: Uint8List.fromList([1, 2, 3]),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.byType(UserMonogram), findsOneWidget);
    });
  });

  group('AvatarCard', () {
    late _MockApiClient apiClient;

    setUp(() => apiClient = _MockApiClient());

    Widget wrap({AuthUser user = _user, Locale locale = const Locale('fr')}) =>
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(initialUser: user),
            ),
            apiClientProvider.overrideWithValue(apiClient),
          ],
          child: MaterialApp(
            locale: locale,
            theme: appDarkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AvatarCard()),
          ),
        );

    Finder preview() => find.descendant(
      of: find.byKey(const Key('settingsAvatarPreview')),
      matching: find.byKey(const Key('userAvatarPreset')),
    );

    testWidgets('offers the monogram and every preset, in both locales', (
      tester,
    ) async {
      for (final locale in const [Locale('fr'), Locale('en')]) {
        await tester.pumpWidget(wrap(locale: locale));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settingsAvatarOption-monogram')),
          findsOneWidget,
        );
        for (final preset in AvatarPreset.values) {
          expect(
            find.byKey(Key('settingsAvatarOption-preset:${preset.name}')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Back to the monogram'), findsOneWidget);
    });

    testWidgets('picking a preset saves it and updates the preview', (
      tester,
    ) async {
      when(
        () => apiClient.put(
          '/auth/me/avatar-choice',
          body: {'avatar': 'preset:amber'},
        ),
      ).thenAnswer((_) async => {'user': _userJson('preset:amber')});
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(preview(), findsNothing);

      await tester.tap(
        find.byKey(const Key('settingsAvatarOption-preset:amber')),
      );
      await tester.pumpAndSettle();

      verify(
        () => apiClient.put(
          '/auth/me/avatar-choice',
          body: {'avatar': 'preset:amber'},
        ),
      ).called(1);
      expect(preview(), findsOneWidget);
    });

    testWidgets('« Revenir au monogramme » is off on the monogram', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final reset = tester.widget<TextButton>(
        find.byKey(const Key('settingsAvatarReset')),
      );
      expect(reset.onPressed, isNull);
    });

    testWidgets('« Revenir au monogramme » goes back to the monogram', (
      tester,
    ) async {
      when(
        () => apiClient.put(
          '/auth/me/avatar-choice',
          body: {'avatar': 'monogram'},
        ),
      ).thenAnswer((_) async => {'user': _userJson('monogram')});
      await tester.pumpWidget(
        wrap(
          user: const AuthUser(
            id: 'u1',
            email: 'ada@example.com',
            displayName: 'ada',
            locale: 'fr',
            currency: 'EUR',
            avatar: PresetChoice(AvatarPreset.lime),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(preview(), findsOneWidget);

      await tester.tap(find.byKey(const Key('settingsAvatarReset')));
      await tester.pumpAndSettle();

      expect(preview(), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('settingsAvatarPreview')),
          matching: find.byType(UserMonogram),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed save shows the banner and keeps the avatar', (
      tester,
    ) async {
      when(
        () => apiClient.put('/auth/me/avatar-choice', body: any(named: 'body')),
      ).thenThrow(ApiFailure.unknown());
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('settingsAvatarOption-preset:iris')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("L'avatar n'a pas pu être enregistré. Réessayez."),
        findsOneWidget,
      );
      expect(preview(), findsNothing);
    });
  });
}
