import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/pictures/pictures.dart';
import 'package:bastide/features/goals/application/goal_image_controller.dart';
import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/domain/goal.dart';
import 'package:flutter/painting.dart' show Rect, Size;
import 'package:flutter/rendering.dart' show Matrix4;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockImaging extends Mock implements PictureImaging {}

class _FakeImage extends Fake implements ui.Image {}

const _stamp = '2026-05-14T10:00:00Z';

Map<String, dynamic> _goalJson({
  String id = 'g1',
  bool image = false,
  String status = 'active',
  int progressMinor = 640000,
  String? reachedOn,
}) => {
  'id': id,
  'name': 'Voyage Japon',
  'target_minor': 1000000,
  'currency': 'EUR',
  'target_date': null,
  'icon': 'flag',
  'color': '#8B8CF9',
  'status': status,
  'progress_minor': progressMinor,
  'progress_pct': progressMinor / 1000000,
  'reached_on': reachedOn,
  'image_updated_at': image ? _stamp : null,
  'created_at': '2026-01-01T00:00:00',
  'updated_at': '2026-05-01T00:00:00',
};

final _png = Uint8List.fromList([9, 9, 9]);
const _crop = Rect.fromLTWH(0, 0, 44, 19);

void main() {
  late _MockApiClient api;
  late _MockImaging imaging;
  late ProviderContainer container;
  var imageOnServer = false;

  setUpAll(() {
    registerFallbackValue(_FakeImage());
    registerFallbackValue(Rect.zero);
    registerFallbackValue(Size.zero);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    imageOnServer = false;
    api = _MockApiClient();
    imaging = _MockImaging();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        pictureImagingProvider.overrideWithValue(imaging),
      ],
    );
    addTearDown(container.dispose);
    when(
      () => api.get('/goals', query: {}),
    ).thenAnswer((_) async => [_goalJson(image: imageOnServer)]);
    when(
      () => api.get('/goals', query: {'status': 'archived'}),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(
      () => api.get('/accounts'),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(
      () => imaging.cropToPng(any(), any(), output: any(named: 'output')),
    ).thenAnswer((_) async => _png);
  });

  void stubUpload() =>
      when(
        () => api.putMultipart(
          '/goals/g1/image',
          fileField: 'file',
          fileName: 'banner.png',
          fileBytes: any(named: 'fileBytes'),
        ),
      ).thenAnswer((_) async {
        imageOnServer = true;
        return _goalJson(image: true);
      });

  Goal loadedGoal() =>
      container.read(goalsControllerProvider).value!.goals.single;

  test('the wire carries the image version and the reached date', () async {
    when(() => api.get('/goals', query: {})).thenAnswer(
      (_) async => [
        _goalJson(
          image: true,
          status: 'reached',
          progressMinor: 1000000,
          reachedOn: '2026-04-12',
        ),
      ],
    );

    await container.read(goalsControllerProvider.future);

    final goal = loadedGoal();
    expect(goal.hasImage, isTrue);
    expect(
      goal.imageRef,
      GoalImageRef(goalId: 'g1', updatedAt: DateTime.parse(_stamp)),
    );
    expect(goal.reachedOn, DateTime(2026, 4, 12));
    expect(goal.remainingMinor, 0);
  });

  test(
    'uploading crops at 44:19 and makes the image the goal banner',
    () async {
      stubUpload();
      await container.read(goalsControllerProvider.future);
      expect(loadedGoal().hasImage, isFalse);

      final saved = await container
          .read(goalImageControllerProvider.notifier)
          .upload('g1', _FakeImage(), _crop);

      expect(saved, isTrue);
      verify(
        () => imaging.cropToPng(any(), _crop, output: bannerUploadSize),
      ).called(1);
      expect(bannerUploadSize.width / bannerUploadSize.height, 44 / 19);
      expect(loadedGoal().hasImage, isTrue);
    },
  );

  test('a refused upload reads with the avatar failure kinds', () async {
    when(
      () => api.putMultipart(
        '/goals/g1/image',
        fileField: 'file',
        fileName: 'banner.png',
        fileBytes: any(named: 'fileBytes'),
      ),
    ).thenThrow(
      const ApiFailure(code: 'GOAL_IMAGE_TOO_LARGE', message: 'Too large.'),
    );
    await container.read(goalsControllerProvider.future);

    final saved = await container
        .read(goalImageControllerProvider.notifier)
        .upload('g1', _FakeImage(), _crop);

    expect(saved, isFalse);
    expect(
      container.read(goalImageControllerProvider).failure,
      PictureUploadFailure.tooLarge,
    );
  });

  test('removing the image goes back to the tomettes banner', () async {
    imageOnServer = true;
    when(() => api.delete('/goals/g1/image')).thenAnswer((_) async {
      imageOnServer = false;
      return _goalJson();
    });
    await container.read(goalsControllerProvider.future);
    expect(loadedGoal().hasImage, isTrue);

    await container.read(goalsControllerProvider.notifier).removeImage('g1');

    expect(loadedGoal().hasImage, isFalse);
    expect(container.read(goalsControllerProvider).value!.actionError, isNull);
  });

  test(
    'a new goal is created, then its image uploaded, and selected',
    () async {
      stubUpload();
      when(
        () => api.post('/goals', body: any(named: 'body')),
      ).thenAnswer((_) async => _goalJson());
      await container.read(goalsControllerProvider.future);

      await container
          .read(goalsControllerProvider.notifier)
          .create(name: 'Voyage Japon', targetMinor: 1000000, image: _png);

      verify(
        () => api.putMultipart(
          '/goals/g1/image',
          fileField: 'file',
          fileName: 'banner.png',
          fileBytes: _png,
        ),
      ).called(1);
      expect(container.read(selectedGoalProvider), 'g1');
    },
  );

  test('an image that fails after the goal is saved is reported', () async {
    when(
      () => api.post('/goals', body: any(named: 'body')),
    ).thenAnswer((_) async => _goalJson());
    when(
      () => api.putMultipart(
        '/goals/g1/image',
        fileField: 'file',
        fileName: 'banner.png',
        fileBytes: any(named: 'fileBytes'),
      ),
    ).thenThrow(
      const ApiFailure(code: 'GOAL_IMAGE_INVALID_IMAGE', message: 'Bad.'),
    );
    await container.read(goalsControllerProvider.future);

    final created = await container
        .read(goalsControllerProvider.notifier)
        .create(name: 'Voyage Japon', targetMinor: 1000000, image: _png);

    expect(created.id, 'g1');
    final error = container.read(goalsControllerProvider).value!.actionError;
    expect(error, isA<GoalImageError>());
    expect(
      (error! as GoalImageError).failure,
      PictureUploadFailure.invalidType,
    );
  });

  test('the crop of a 44:19 window keeps 44:19 and stays on the picture', () {
    const viewport = Size(392, 392 * 19 / 44);
    const image = Size(1200, 800);

    final centred = cropRectIn(
      imageSize: image,
      viewport: viewport,
      transform: Matrix4.identity(),
    );
    expect(centred.width / centred.height, closeTo(44 / 19, 1e-9));
    expect(centred.width, image.width);

    final dragged = cropRectIn(
      imageSize: image,
      viewport: viewport,
      transform: Matrix4.translationValues(-5000, -5000, 0),
    );
    expect(dragged.right, image.width);
    expect(dragged.bottom, image.height);
  });
}
