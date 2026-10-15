import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';
import 'package:goodfood_ecosystem/features/menu/data/repositories/menu_repository.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/meal_local_cache.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/menu_remote_service.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/add_edit_meal_screen.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_management_cubit.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_management_state.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/meal_image.dart';

void main() {
  test('SQLite cache persists meals after the first Firebase sync', () async {
    final directory = await Directory.systemTemp.createTemp('goodfood-menu-');
    final databasePath = p.join(directory.path, 'meals.db');
    final firstCache = SqliteMealLocalCache(databasePath: databasePath);
    const meal = MealModel(
      id: 'firebase-meal-1',
      name: 'Cached meal',
      category: MealCategory.desserts,
      price: 5.5,
      imageUrl: 'https://example.com/meal.png',
      description: 'Saved from Firebase',
      isAvailable: false,
    );

    expect(await firstCache.readMeals(), isNull);
    await firstCache.replaceMeals([meal]);
    await firstCache.close();

    final reopenedCache = SqliteMealLocalCache(databasePath: databasePath);
    final cached = await reopenedCache.readMeals();
    expect(cached?.meals, hasLength(1));
    expect(cached!.meals.single.id, meal.id);
    expect(cached.meals.single.name, meal.name);
    expect(cached.meals.single.category, meal.category);
    expect(cached.meals.single.price, meal.price);
    expect(cached.meals.single.imageUrl, meal.imageUrl);
    expect(cached.meals.single.description, meal.description);
    expect(cached.meals.single.isAvailable, meal.isAvailable);
    await reopenedCache.replaceMeals([]);
    expect(await reopenedCache.readMeals(), isA<CachedMeals>());
    await reopenedCache.close();
    await directory.delete(recursive: true);
  });

  test(
    'repository emits cached meals before refreshing from Firebase',
    () async {
      const cachedMeal = MealModel(
        id: 'cached-meal',
        name: 'Cached first',
        category: MealCategory.starters,
        price: 3,
        imageUrl: '',
      );
      const remoteMeal = MealModel(
        id: 'remote-meal',
        name: 'Latest from Firebase',
        category: MealCategory.mainCourse,
        price: 9,
        imageUrl: '',
      );
      final cache = _InMemoryMealLocalCache(CachedMeals([cachedMeal]));
      final service = _InMemoryMenuRemoteService()..seed([remoteMeal]);
      final repository = MenuRepository(service, mealLocalCache: cache);

      final meals = await repository.watchAllMeals().take(2).toList();

      expect(meals, [
        [cachedMeal],
        [remoteMeal],
      ]);
      expect(cache.snapshot?.meals, [remoteMeal]);
      await service.dispose();
    },
  );

  test(
    'repository does not cache unconfirmed Firestore cache snapshots',
    () async {
      const sdkCachedMeal = MealModel(
        id: 'sdk-cache-meal',
        name: 'Not server-confirmed',
        category: MealCategory.mainCourse,
        price: 6,
        imageUrl: '',
      );
      final cache = _InMemoryMealLocalCache();
      final service = _InMemoryMenuRemoteService()
        ..seed([sdkCachedMeal], isFromCache: true);
      final repository = MenuRepository(service, mealLocalCache: cache);

      final meals = await repository.watchAllMeals().take(1).toList();

      expect(meals.single, [sdkCachedMeal]);
      expect(cache.snapshot, isNull);
      await service.dispose();
    },
  );

  test('cached meals remain available if Firebase refresh is denied', () async {
    const cachedMeal = MealModel(
      id: 'cached-meal',
      name: 'Available offline',
      category: MealCategory.starters,
      price: 3,
      imageUrl: '',
    );
    final service = _DeniedWatchMenuRemoteService();
    final cubit = MenuManagementCubit(
      MenuRepository(
        service,
        mealLocalCache: _InMemoryMealLocalCache(CachedMeals([cachedMeal])),
      ),
    )..watch();

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.status, ManagementStatus.success);
    expect(cubit.state.meals.single.name, cachedMeal.name);
    await cubit.close();
    await service.dispose();
  });

  testWidgets('add screen returns to the main product list', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: _EditorTestHost(
          meal: null,
          onOpen: (context, meal) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddEditMealScreen(meal: meal),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View added products'));
    await tester.pumpAndSettle();

    expect(find.text('Open editor'), findsOneWidget);
    expect(find.text('Add New Meal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewing products asks before discarding entered meal data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: _EditorTestHost(
          meal: null,
          onOpen: (context, meal) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddEditMealScreen(meal: meal),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meal-name')),
      'Unsaved meal',
    );
    await tester.tap(find.text('View added products'));
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Stay here'));
    await tester.pumpAndSettle();
    expect(find.text('Add New Meal'), findsOneWidget);
    expect(find.text('Unsaved meal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'save reports a pending result when Firebase does not respond',
    () async {
      final service = _DelayedAddMenuRemoteService();
      final cubit = MenuManagementCubit(
        MenuRepository(service),
        saveTimeout: const Duration(milliseconds: 1),
      );
      const meal = MealModel(
        id: '',
        name: 'Pending meal',
        category: MealCategory.mainCourse,
        price: 7,
        imageUrl: '',
      );

      final result = await cubit.save(meal);

      expect(result, MealSaveResult.pending);
      service.pendingAdd.complete('saved-later');
      await cubit.close();
      await service.dispose();
    },
  );

  test('Firebase permission errors explain the missing admin access', () async {
    final service = _DeniedAddMenuRemoteService();
    final repository = MenuRepository(service);
    const meal = MealModel(
      id: '',
      name: 'Denied meal',
      category: MealCategory.mainCourse,
      price: 7,
      imageUrl: '',
    );

    await expectLater(
      repository.addMeal(meal),
      throwsA(
        isA<MenuFailure>().having(
          (error) => error.message,
          'message',
          contains('Admin access is not configured'),
        ),
      ),
    );
    await service.dispose();
  });

  testWidgets('admin can add and edit a meal from the editor', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMenuRemoteService();
    final cubit = MenuManagementCubit(MenuRepository(service))..watch();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: _EditorTestHost(
            meal: null,
            onOpen: (context, _) {
              final meal = service.meals.isEmpty
                  ? null
                  : service.meals.values.single;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddEditMealScreen(meal: meal),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meal-name')),
      'Test Admin Meal',
    );
    await tester.enterText(find.byKey(const ValueKey('meal-price')), '12.50');
    await tester.tap(find.text('Save Meal'));
    await tester.pumpAndSettle();

    expect(service.meals, hasLength(1));
    var savedMeal = service.meals.values.single;
    expect(savedMeal.name, 'Test Admin Meal');
    expect(savedMeal.price, 12.5);
    expect(cubit.state.meals, contains(savedMeal));

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meal-name')),
      'Updated Admin Meal',
    );
    await tester.enterText(find.byKey(const ValueKey('meal-price')), '15.75');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    savedMeal = service.meals.values.single;
    expect(service.meals, hasLength(1));
    expect(savedMeal.id, isNotEmpty);
    expect(savedMeal.name, 'Updated Admin Meal');
    expect(savedMeal.price, 15.75);
    expect(cubit.state.meals, contains(savedMeal));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
    await service.dispose();
  });

  test('admin can delete a meal and the live admin list updates', () async {
    final service = _InMemoryMenuRemoteService();
    final repository = MenuRepository(service);
    final cubit = MenuManagementCubit(repository)..watch();
    await Future<void>.delayed(Duration.zero);

    final meal = const MealModel(
      id: '',
      name: 'Meal to delete',
      category: MealCategory.starters,
      price: 4.5,
      imageUrl: '',
    );
    await repository.addMeal(meal);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.meals, hasLength(1));

    final id = cubit.state.meals.single.id;
    await cubit.delete(id);
    await Future<void>.delayed(Duration.zero);

    expect(service.meals, isEmpty);
    expect(cubit.state.meals, isEmpty);
    await cubit.close();
    await service.dispose();
  });

  testWidgets('admin can preview and save an image from its URL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMenuRemoteService();
    final cubit = MenuManagementCubit(MenuRepository(service));
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: _EditorTestHost(
            meal: null,
            onOpen: (context, meal) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddEditMealScreen(meal: meal),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meal-name')),
      'URL Image Meal',
    );
    await tester.enterText(find.byKey(const ValueKey('meal-price')), '8.25');
    await tester.enterText(
      find.byKey(const ValueKey('meal-image-url')),
      'https://example.com/meal.jpg',
    );
    await tester.pump();

    final preview = tester.widget<MealImage>(
      find.byKey(const ValueKey('meal-image-preview')),
    );
    expect(preview.url, 'https://example.com/meal.jpg');

    await tester.tap(find.text('Save Meal'));
    await tester.pumpAndSettle();
    expect(
      service.meals.values.single.imageUrl,
      'https://example.com/meal.jpg',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
    await service.dispose();
  });

  testWidgets('admin must enter a valid HTTP image URL', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMenuRemoteService();
    final cubit = MenuManagementCubit(MenuRepository(service));
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: _EditorTestHost(
            meal: null,
            onOpen: (context, meal) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddEditMealScreen(meal: meal),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meal-name')),
      'Invalid URL',
    );
    await tester.enterText(find.byKey(const ValueKey('meal-price')), '8.25');
    await tester.enterText(
      find.byKey(const ValueKey('meal-image-url')),
      'not-a-url',
    );
    await tester.tap(find.text('Save Meal'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid image URL starting with http:// or https://.'),
      findsOneWidget,
    );
    expect(service.meals, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
    await service.dispose();
  });

  testWidgets('admin cannot save a meal with an invalid price', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMenuRemoteService();
    final cubit = MenuManagementCubit(MenuRepository(service));
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: _EditorTestHost(
            meal: null,
            onOpen: (context, meal) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddEditMealScreen(meal: meal),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meal-name')),
      'Invalid Meal',
    );
    await tester.enterText(find.byKey(const ValueKey('meal-price')), '-1');
    await tester.tap(find.text('Save Meal'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid price.'), findsOneWidget);
    expect(service.meals, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
    await service.dispose();
  });
}

class _EditorTestHost extends StatelessWidget {
  const _EditorTestHost({required this.meal, required this.onOpen});

  final MealModel? meal;
  final void Function(BuildContext context, MealModel? meal) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => onOpen(context, meal),
        child: const Text('Open editor'),
      ),
    ),
  );
}

class _InMemoryMenuRemoteService implements MenuRemoteService {
  final Map<String, MealModel> meals = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  var _isFromCache = false;
  var _nextId = 0;

  void seed(List<MealModel> values, {bool isFromCache = false}) {
    meals
      ..clear()
      ..addEntries(values.map((meal) => MapEntry(meal.id, meal)));
    _isFromCache = isFromCache;
  }

  List<MealModel> _filtered({MealCategory? category}) => meals.values
      .where((meal) => category == null || meal.category == category)
      .toList(growable: false);

  @override
  Stream<RemoteMealsSnapshot> watchAll({MealCategory? category}) async* {
    yield RemoteMealsSnapshot(
      meals: _filtered(category: category),
      isFromCache: _isFromCache,
      hasPendingWrites: false,
    );
    await for (final _ in _changes.stream) {
      yield RemoteMealsSnapshot(
        meals: _filtered(category: category),
        isFromCache: _isFromCache,
        hasPendingWrites: false,
      );
    }
  }

  @override
  Future<String> add(MealModel meal) async {
    final id = 'test-meal-${_nextId++}';
    meals[id] = _withId(meal, id);
    _changes.add(null);
    return id;
  }

  @override
  Future<void> update(MealModel meal) async {
    meals[meal.id] = meal;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    meals.remove(id);
    _changes.add(null);
  }

  @override
  Future<void> setAvailability(String id, bool value) async {
    final meal = meals[id];
    if (meal != null) {
      meals[id] = _withId(meal, id, isAvailable: value);
      _changes.add(null);
    }
  }

  @override
  Future<MealModel?> fetchMeal(String id) async => meals[id];

  @override
  Future<MealsPage> fetchPage({
    MealCategory? category,
    String query = '',
    MealDoc? after,
  }) async {
    final results = _filtered(category: category)
        .where((meal) => meal.isAvailable)
        .where(
          (meal) => meal.name.toLowerCase().startsWith(query.toLowerCase()),
        )
        .toList(growable: false);
    return MealsPage(meals: results, cursor: null, hasMore: false);
  }

  MealModel _withId(MealModel meal, String id, {bool? isAvailable}) =>
      MealModel(
        id: id,
        name: meal.name,
        category: meal.category,
        price: meal.price,
        imageUrl: meal.imageUrl,
        description: meal.description,
        isAvailable: isAvailable ?? meal.isAvailable,
      );

  Future<void> dispose() => _changes.close();
}

class _InMemoryMealLocalCache implements MealLocalCache {
  _InMemoryMealLocalCache([this.snapshot]);

  CachedMeals? snapshot;

  @override
  Future<CachedMeals?> readMeals() async => snapshot;

  @override
  Future<void> replaceMeals(List<MealModel> meals) async {
    snapshot = CachedMeals(List.unmodifiable(meals));
  }
}

class _DelayedAddMenuRemoteService extends _InMemoryMenuRemoteService {
  final Completer<String> pendingAdd = Completer<String>();

  @override
  Future<String> add(MealModel meal) => pendingAdd.future;
}

class _DeniedAddMenuRemoteService extends _InMemoryMenuRemoteService {
  @override
  Future<String> add(MealModel meal) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

class _DeniedWatchMenuRemoteService extends _InMemoryMenuRemoteService {
  @override
  Stream<RemoteMealsSnapshot> watchAll({MealCategory? category}) async* {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}
