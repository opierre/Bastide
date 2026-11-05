import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/application/avatar_picture_controllers.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/domain/avatar_choice.dart';
import 'package:bastide/features/auth/domain/avatar_picture.dart';
import 'package:bastide/features/auth/presentation/avatar_card.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_auth_controller.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAvatarFiles extends Mock implements AvatarFiles {}

class _MockAvatarImaging extends Mock implements AvatarImaging {}

class _FakeImage extends Fake implements ui.Image {}

AuthUser _user(AvatarChoice avatar) => AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'ada',
  locale: 'fr',
  currency: 'EUR',
  avatar: avatar,
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

// A 1×1 transparent PNG: what the backend serves back.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final _cropped = Uint8List.fromList([9, 9, 9]);

ApiBytesResponse _served({String etag = '"1"'}) =>
    ApiBytesResponse(bytes: _png, headers: {'etag': etag});

final _notModified = ApiBytesResponse(
  bytes: Uint8List(0),
  headers: {},
  statusCode: 304,
);

PickedPictureFile _file(int length) =>
    (length: length, read: () async => Uint8List.fromList([1, 2, 3]));

void main() {
  late _MockApiClient api;
  late _MockAvatarFiles files;
  late _MockAvatarImaging imaging;

  setUpAll(() {
    registerFallbackValue(_FakeImage());
    registerFallbackValue(Rect.zero);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    api = _MockApiClient();
    files = _MockAvatarFiles();
    imaging = _MockAvatarImaging();
  });

  List<Override> overrides(AuthUser user) => [
    authControllerProvider.overrideWith(
      () => FakeAuthController(initialUser: user),
    ),
    apiClientProvider.overrideWithValue(api),
    avatarFilesProvider.overrideWithValue(files),
    avatarImagingProvider.overrideWithValue(imaging),
  ];

  group('cropRectFor', () {
    test('the opening, centred position crops the middle square', () {
      const size = Size(400, 200);
      final scale = coverScale(size, 100);

      final rect = cropRectFor(
        imageSize: size,
        viewport: 100,
        transform: Matrix4.translationValues(-(400 * scale - 100) / 2, 0, 0),
      );

      expect(rect, const Rect.fromLTWH(100, 0, 200, 200));
    });

    test('zooming in narrows the square around where the window sits', () {
      const size = Size(200, 200);
      // Zoomed ×2, then moved so the window shows the bottom-right quarter.
      final transform = Matrix4.translationValues(-100, -100, 0)
        ..scaleByDouble(2, 2, 1, 1);

      final rect = cropRectFor(
        imageSize: size,
        viewport: 100,
        transform: transform,
      );

      expect(rect, const Rect.fromLTWH(100, 100, 100, 100));
    });

    test('never samples outside the picture', () {
      final rect = cropRectFor(
        imageSize: const Size(300, 300),
        viewport: 100,
        transform: Matrix4.translationValues(50, 50, 0),
      );

      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.right, lessThanOrEqualTo(300));
    });
  });

  group('AvatarPictureController', () {
    Future<ProviderContainer> container(AuthUser user) async {
      final container = ProviderContainer(overrides: overrides(user));
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      return container;
    }

    test('fetches nothing while the avatar is not a picture', () async {
      final c = await container(_user(const MonogramChoice()));

      expect(await c.read(avatarPictureProvider.future), isNull);
      verifyNever(
        () => api.getBytes(any(), ifNoneMatch: any(named: 'ifNoneMatch')),
      );
    });

    test('keeps the bytes it has when the ETag still matches', () async {
      when(
        () => api.getBytes('/auth/me/avatar'),
      ).thenAnswer((_) async => _served());
      when(
        () => api.getBytes('/auth/me/avatar', ifNoneMatch: '"1"'),
      ).thenAnswer((_) async => _notModified);
      final c = await container(_user(const PictureChoice()));

      final first = await c.read(avatarPictureProvider.future);
      await c.read(avatarPictureProvider.notifier).refresh();

      expect(first?.bytes, _png);
      expect(c.read(avatarPictureProvider).value?.bytes, _png);
      verify(
        () => api.getBytes('/auth/me/avatar', ifNoneMatch: '"1"'),
      ).called(1);
    });

    test('falls back to no picture when the backend has none', () async {
      when(
        () => api.getBytes('/auth/me/avatar'),
      ).thenThrow(const ApiFailure(code: 'AVATAR_NOT_FOUND', message: 'none'));
      final c = await container(_user(const PictureChoice()));

      expect(await c.read(avatarPictureProvider.future), isNull);
    });
  });

  group('ProfilePictureController', () {
    Future<ProviderContainer> container() async {
      final c = ProviderContainer(
        overrides: overrides(_user(const PresetChoice(AvatarPreset.teal))),
      );
      addTearDown(c.dispose);
      await c.read(authControllerProvider.future);
      // Keep the auto-disposed controller alive between calls.
      c.listen(profilePictureControllerProvider, (_, _) {});
      return c;
    }

    test('refuses a file over the limit without reading it', () async {
      var read = false;
      when(() => files.pick()).thenAnswer(
        (_) async => (
          length: maxAvatarUploadBytes + 1,
          read: () async {
            read = true;
            return Uint8List(0);
          },
        ),
      );
      final c = await container();

      final image = await c
          .read(profilePictureControllerProvider.notifier)
          .pick();

      expect(image, isNull);
      expect(read, isFalse);
      expect(
        c.read(profilePictureControllerProvider).failure,
        AvatarUploadFailure.tooLarge,
      );
    });

    test('refuses a file that does not decode as a picture', () async {
      when(() => files.pick()).thenAnswer((_) async => _file(10));
      when(() => imaging.decode(any())).thenThrow(Exception('not an image'));
      final c = await container();

      final image = await c
          .read(profilePictureControllerProvider.notifier)
          .pick();

      expect(image, isNull);
      expect(
        c.read(profilePictureControllerProvider).failure,
        AvatarUploadFailure.invalidType,
      );
    });

    test('a cancelled pick changes nothing', () async {
      when(() => files.pick()).thenAnswer((_) async => null);
      final c = await container();

      expect(
        await c.read(profilePictureControllerProvider.notifier).pick(),
        isNull,
      );
      expect(c.read(profilePictureControllerProvider).failure, isNull);
    });

    test('a refused upload keeps the current avatar', () async {
      when(
        () => imaging.cropToPng(any(), any()),
      ).thenAnswer((_) async => _cropped);
      when(
        () => api.putMultipart(
          '/auth/me/avatar',
          fileField: 'file',
          fileName: any(named: 'fileName'),
          fileBytes: _cropped,
        ),
      ).thenThrow(
        const ApiFailure(code: 'AVATAR_INVALID_IMAGE', message: 'no'),
      );
      final c = await container();

      final saved = await c
          .read(profilePictureControllerProvider.notifier)
          .upload(_FakeImage(), Rect.zero);

      expect(saved, isFalse);
      expect(
        c.read(profilePictureControllerProvider).failure,
        AvatarUploadFailure.invalidType,
      );
      expect(
        c.read(authControllerProvider).value?.avatar,
        const PresetChoice(AvatarPreset.teal),
      );
    });
  });

  group('AvatarCard with a picture', () {
    Widget wrap(AuthUser user, {Locale locale = const Locale('fr')}) =>
        ProviderScope(
          overrides: overrides(user),
          child: MaterialApp(
            locale: locale,
            theme: appDarkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AvatarCard()),
          ),
        );

    Finder previewPicture() => find.descendant(
      of: find.byKey(const Key('settingsAvatarPreview')),
      matching: find.byKey(const Key('userAvatarPicture')),
    );

    testWidgets('a picked and cropped picture becomes the avatar', (
      tester,
    ) async {
      final image = await tester.runAsync(() => createTestImage(width: 40));
      when(() => files.pick()).thenAnswer((_) async => _file(10));
      when(() => imaging.decode(any())).thenAnswer((_) async => image!);
      when(
        () => imaging.cropToPng(any(), any()),
      ).thenAnswer((_) async => _cropped);
      when(
        () => api.putMultipart(
          '/auth/me/avatar',
          fileField: 'file',
          fileName: any(named: 'fileName'),
          fileBytes: _cropped,
        ),
      ).thenAnswer((_) async => {'user': _userJson('image')});
      when(
        () => api.getBytes(any(), ifNoneMatch: any(named: 'ifNoneMatch')),
      ).thenAnswer((_) async => _served());
      await tester.pumpWidget(wrap(_user(const MonogramChoice())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsAvatarChoosePicture')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('avatarCropViewport')), findsOneWidget);

      await tester.tap(find.byKey(const Key('avatarCropSave')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avatarCropViewport')), findsNothing);
      expect(previewPicture(), findsOneWidget);
      expect(
        find.byKey(const Key('settingsAvatarRemovePicture')),
        findsOneWidget,
      );
    });

    testWidgets('a too-large file says so and opens no crop step', (
      tester,
    ) async {
      when(
        () => files.pick(),
      ).thenAnswer((_) async => _file(maxAvatarUploadBytes + 1));
      await tester.pumpWidget(wrap(_user(const MonogramChoice())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsAvatarChoosePicture')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avatarCropViewport')), findsNothing);
      expect(
        find.text(
          'Cette image est trop lourde : choisissez un fichier de moins de 10 Mo.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a file of the wrong type says so, in English too', (
      tester,
    ) async {
      when(() => files.pick()).thenAnswer((_) async => _file(10));
      when(() => imaging.decode(any())).thenThrow(Exception('not an image'));
      await tester.pumpWidget(
        wrap(_user(const MonogramChoice()), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsAvatarChoosePicture')));
      await tester.pumpAndSettle();

      expect(
        find.text("This file isn't a PNG, JPEG or WebP picture."),
        findsOneWidget,
      );
    });

    testWidgets('a picture the backend refuses keeps the modal and avatar', (
      tester,
    ) async {
      final image = await tester.runAsync(() => createTestImage(width: 40));
      when(() => files.pick()).thenAnswer((_) async => _file(10));
      when(() => imaging.decode(any())).thenAnswer((_) async => image!);
      when(
        () => imaging.cropToPng(any(), any()),
      ).thenAnswer((_) async => _cropped);
      when(
        () => api.putMultipart(
          any(),
          fileField: any(named: 'fileField'),
          fileName: any(named: 'fileName'),
          fileBytes: any(named: 'fileBytes'),
        ),
      ).thenThrow(const ApiFailure(code: 'AVATAR_TOO_LARGE', message: 'big'));
      await tester.pumpWidget(wrap(_user(const MonogramChoice())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsAvatarChoosePicture')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatarCropSave')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avatarCropViewport')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('avatarCropViewport')).hitTestable(),
          matching: find.byType(RawImage),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Cette image est trop lourde : choisissez un fichier de moins de 10 Mo.',
        ),
        findsWidgets,
      );
      expect(previewPicture(), findsNothing);
    });

    testWidgets('« Retirer la photo » brings back the previous default', (
      tester,
    ) async {
      when(
        () => api.getBytes(any(), ifNoneMatch: any(named: 'ifNoneMatch')),
      ).thenAnswer((_) async => _served());
      when(
        () => api.delete('/auth/me/avatar'),
      ).thenAnswer((_) async => {'user': _userJson('preset:pink')});
      await tester.pumpWidget(wrap(_user(const PictureChoice())));
      await tester.pumpAndSettle();
      expect(previewPicture(), findsOneWidget);

      await tester.tap(find.byKey(const Key('settingsAvatarRemovePicture')));
      await tester.pumpAndSettle();

      expect(previewPicture(), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('settingsAvatarPreview')),
          matching: find.byKey(const Key('userAvatarPreset')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settingsAvatarReset')), findsOneWidget);
    });
  });
}
