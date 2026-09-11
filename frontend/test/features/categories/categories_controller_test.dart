import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/categories/application/categories_controller.dart';
import 'package:finstride/features/categories/domain/category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _categoryJson({
  String id = 'c1',
  String? userId,
  String? parentId,
  String name = 'category.food',
  String kind = 'expense',
  bool isSystem = true,
}) => {
  'id': id,
  'user_id': userId,
  'parent_id': parentId,
  'name': name,
  'kind': kind,
  'icon': 'rice_bowl',
  'color': '#5AA9FF',
  'is_system': isSystem,
};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  test('build loads the catalog', () async {
    when(() => apiClient.get('/categories')).thenAnswer(
      (_) async => [
        _categoryJson(),
        _categoryJson(id: 'c2', userId: 'u1', name: 'Épargne projet', isSystem: false),
      ],
    );

    final categories = await container.read(categoriesControllerProvider.future);

    expect(categories, hasLength(2));
    expect(categories.first.isSystem, isTrue);
    expect(categories.last.name, 'Épargne projet');
    expect(categories.last.isSystem, isFalse);
  });

  test('create appends the new category', () async {
    when(() => apiClient.get('/categories')).thenAnswer((_) async => <dynamic>[]);
    when(() => apiClient.post('/categories', body: any(named: 'body'))).thenAnswer(
      (_) async =>
          _categoryJson(id: 'c9', userId: 'u1', name: 'Épargne projet', isSystem: false),
    );

    await container.read(categoriesControllerProvider.future);
    final created = await container
        .read(categoriesControllerProvider.notifier)
        .create(name: 'Épargne projet', kind: 'expense', icon: 'sell', color: '#64748B');

    expect(created.id, 'c9');
    expect(container.read(categoriesControllerProvider).value, hasLength(1));
  });

  test('updateCategory replaces the row in place', () async {
    when(
      () => apiClient.get('/categories'),
    ).thenAnswer((_) async => [_categoryJson(id: 'c1', userId: 'u1', isSystem: false)]);
    when(() => apiClient.patch('/categories/c1', body: any(named: 'body'))).thenAnswer(
      (_) async => _categoryJson(id: 'c1', userId: 'u1', name: 'Renommée', isSystem: false),
    );

    await container.read(categoriesControllerProvider.future);
    await container
        .read(categoriesControllerProvider.notifier)
        .updateCategory('c1', name: 'Renommée');

    expect(container.read(categoriesControllerProvider).value!.single.name, 'Renommée');
  });

  test('a rejected patch of a system category leaves the tree untouched', () async {
    when(() => apiClient.get('/categories')).thenAnswer((_) async => [_categoryJson()]);
    when(
      () => apiClient.patch('/categories/c1', body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'CATEGORY_NOT_FOUND', message: 'Category not found.'));

    await container.read(categoriesControllerProvider.future);

    await expectLater(
      () => container
          .read(categoriesControllerProvider.notifier)
          .updateCategory('c1', name: 'Forcée'),
      throwsA(isA<ApiFailure>()),
    );
    expect(container.read(categoriesControllerProvider).value!.single.name, 'category.food');
  });

  test('delete drops the category and its subcategories', () async {
    when(() => apiClient.get('/categories')).thenAnswer(
      (_) async => [
        _categoryJson(id: 'c1', userId: 'u1', isSystem: false),
        _categoryJson(id: 'c2', userId: 'u1', parentId: 'c1', isSystem: false),
        _categoryJson(id: 'c3', userId: 'u1', isSystem: false),
      ],
    );
    when(() => apiClient.delete('/categories/c1')).thenAnswer((_) async => null);

    await container.read(categoriesControllerProvider.future);
    await container.read(categoriesControllerProvider.notifier).delete('c1');

    expect(
      container.read(categoriesControllerProvider).value!.map((c) => c.id),
      ['c3'],
    );
  });

  test('the tree nests subcategories under their parent, keeping backend order', () async {
    when(() => apiClient.get('/categories')).thenAnswer(
      (_) async => [
        _categoryJson(id: 'food', name: 'category.food'),
        _categoryJson(id: 'groceries', parentId: 'food', name: 'category.food.groceries'),
        _categoryJson(id: 'housing', name: 'category.housing'),
      ],
    );

    await container.read(categoriesControllerProvider.future);
    final tree = container.read(categoryTreeProvider).value!;

    expect(tree.map((node) => node.category.id), ['food', 'housing']);
    expect(tree.first.children.map((child) => child.id), ['groceries']);
    expect(tree.last.children, isEmpty);
  });

  test('a subcategory with no parent in the list is promoted rather than dropped', () {
    final tree = buildCategoryTree(const [
      AppCategory(
        id: 'orphan',
        userId: 'u1',
        parentId: 'missing',
        name: 'Orpheline',
        kind: 'expense',
        icon: 'sell',
        color: '#64748B',
        isSystem: false,
      ),
    ]);

    expect(tree.single.category.id, 'orphan');
  });
}
