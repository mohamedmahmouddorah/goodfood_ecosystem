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
import 'package:goodfood_ecosystem/features/menu/presentation/view/menu_management_screen.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_cubit.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_management_cubit.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_management_state.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_state.dart';
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

  test('SQLite cache keeps pending admin changes across restarts', () async {
    final directory = await Directory.systemTemp.createTemp('goodfood-menu-');
    final databasePath = p.join(directory.path, 'meals.db');
    final firstCache = SqliteMealLocalCache(databasePath: databasePath);
    const original = MealModel(
      id: 'existing-meal',
      name: 'Original',
      category: MealCategory.mainCourse,
      price: 8,
      imageUrl: '',
    );
    const addedOffline = MealModel(
      id: 'offline-meal',
      name: 'Added offline',
      category: MealCategory.starters,
      price: 4,
      imageUrl: '',
      isAvailable: false,
    );

    await firstCache.replaceMeals([original]);
    await firstCache.upsertMeal(original.copyWith(name: 'Edited offline'));
    await firstCache.upsertMeal(addedOffline);
    await firstCache.removeMeal(original.id);
    await firstCache.close();

    final reopenedCache = SqliteMealLocalCache(databasePath: databasePath);
    final cachedMeals = await reopenedCache.readMeals();
    expect(cachedMeals?.meals, hasLength(1));
    expect(cachedMeals!.meals.single.id, addedOffline.id);
    expect(cachedMeals.meals.single.name, addedOffline.name);
    expect(cachedMeals.meals.single.isAvailable, isFalse);
    await reopenedCache.close();
    await directory.delete(recursive: true);
  });

  test('customer refresh preserves hidden meals in the admin cache', () async {
    final directory = await Directory.systemTemp.createTemp('goodfood-menu-');
    final databasePath = p.join(directory.path, 'meals.db');
    final cache = SqliteMealLocalCache(databasePath: databasePath);
    const visibleMeal = MealModel(
      id: 'still-visible',
      name: 'Updated visible',
      category: MealCategory.starters,
      price: 4,
      imageUrl: '',
    );
    const newlyHiddenMeal = MealModel(
      id: 'now-hidden',
      name: 'Now hidden',
      category: MealCategory.desserts,
      price: 6,
      imageUrl: '',
    );
    const alreadyHiddenMeal = MealModel(
      id: 'already-hidden',
      name: 'Hidden product',
      category: MealCategory.drinks,
      price: 3,
      imageUrl: '',
      isAvailable: false,
    );

    await cache.replaceMeals([newlyHiddenMeal, alreadyHiddenMeal]);
    await cache.replaceAvailableMeals([visibleMeal]);
    final cached = (await cache.readMeals())!.meals;

    expect(cached.map((meal) => meal.id).toSet(), {
      visibleMeal.id,
      newlyHiddenMeal.id,
      alreadyHiddenMeal.id,
    });
    expect(
      cached.singleWhere((meal) => meal.id == visibleMeal.id).isAvailable,
      isTrue,
    );
    expect(
      cached.singleWhere((meal) => meal.id == newlyHiddenMeal.id).isAvailable,
      isFalse,
    );
    expect(
      cached.singleWhere((meal) => meal.id == alreadyHiddenMeal.id).isAvailable,
      isFalse,
    );
    await cache.close();
    await directory.delete(recursive: true);
  });

  test(
    'admin changes are cached before their Firebase writes complete',
    () async {
      const original = MealModel(
        id: 'offline-edit',
        name: 'Original',
        category: MealCategory.mainCourse,
        price: 8,
        imageUrl: '',
      );
      final service = _DelayedWriteMenuRemoteService()..seed([original]);
      final cache = _InMemoryMealLocalCache(CachedMeals([original]));
      final repository = MenuRepository(service, mealLocalCache: cache);

      final update = repository.updateMeal(
        original.copyWith(name: 'Edited offline'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cache.snapshot!.meals.single.name, 'Edited offline');
      service.completePendingWrite();
      await update;

      final toggle = repository.setAvailability(
        original.id,
        false,
        meal: original.copyWith(name: 'Edited offline'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cache.snapshot!.meals.single.isAvailable, isFalse);
      service.completePendingWrite();
      await toggle;

      final delete = repository.deleteMeal(
        original.id,
        meal: original.copyWith(name: 'Edited offline', isAvailable: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cache.snapshot!.meals, isEmpty);
      service.completePendingWrite();
      await delete;
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

  test(
    'repository emits pending Firestore changes over its older local cache',
    () async {
      const cachedMeal = MealModel(
        id: 'cached-meal',
        name: 'Older local value',
        category: MealCategory.starters,
        price: 3,
        imageUrl: '',
      );
      const pendingMeal = MealModel(
        id: 'pending-meal',
        name: 'Saved while offline',
        category: MealCategory.mainCourse,
        price: 8,
        imageUrl: '',
      );
      final cache = _InMemoryMealLocalCache(CachedMeals([cachedMeal]));
      final service = _InMemoryMenuRemoteService()
        ..seed([pendingMeal], isFromCache: true);
      final repository = MenuRepository(service, mealLocalCache: cache);

      final meals = await repository.watchAllMeals().take(2).toList();

      expect(meals, [
        [cachedMeal],
        [pendingMeal],
      ]);
      expect(cache.snapshot?.meals, [cachedMeal]);
      await service.dispose();
    },
  );

  test(
    'admin repository includes hidden products for the visibility filter',
    () async {
      const hiddenMeal = MealModel(
        id: 'hidden-from-customer',
        name: 'Hidden product',
        category: MealCategory.mainCourse,
        price: 10,
        imageUrl: '',
        isAvailable: false,
      );
      final service = _InMemoryMenuRemoteService()..seed([hiddenMeal]);
      final repository = MenuRepository(service);

      final meals = await repository.watchAllMeals().first;

      expect(meals, [hiddenMeal]);
      await service.dispose();
    },
  );

  test('customer menu streams Firebase updates and filters locally', () async {
    const starter = MealModel(
      id: 'starter',
      name: 'Garden Salad',
      category: MealCategory.starters,
      price: 4,
      imageUrl: '',
    );
    const main = MealModel(
      id: 'main',
      name: 'Grilled Chicken',
      category: MealCategory.mainCourse,
      price: 12,
      imageUrl: '',
    );
    final service = _InMemoryMenuRemoteService()..seed([starter, main]);
    final cubit = MenuCubit(MenuRepository(service));
    final initialMenu = cubit.stream.firstWhere(
      (state) => state.status == MenuStatus.success,
    );

    await cubit.load();
    await initialMenu;
    expect(cubit.state.meals, [starter, main]);

    cubit.selectCategory(MealCategory.starters);
    expect(cubit.state.meals, [starter]);

    await Future<void>.delayed(Duration.zero);
    await service.add(
      const MealModel(
        id: '',
        name: 'Tomato Soup',
        category: MealCategory.starters,
        price: 5,
        imageUrl: '',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.meals.map((meal) => meal.name), [
      'Garden Salad',
      'Tomato Soup',
    ]);

    await cubit.close();
    await service.dispose();
  });

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

  test(
    'hidden products stay in admin list but are excluded from customers',
    () async {
      const visibleMeal = MealModel(
        id: 'visible-meal',
        name: 'Visible meal',
        category: MealCategory.mainCourse,
        price: 8,
        imageUrl: '',
      );
      const hiddenMeal = MealModel(
        id: 'hidden-meal',
        name: 'Hidden meal',
        category: MealCategory.mainCourse,
        price: 9,
        imageUrl: '',
        isAvailable: false,
      );
      final service = _InMemoryMenuRemoteService()
        ..seed([visibleMeal, hiddenMeal]);
      final adminMeals = await service.watchAll(includeHidden: true).first;
      final customerMeals = await service.watchAvailable().first;
      expect(adminMeals.meals, contains(hiddenMeal));
      expect(customerMeals.meals, [visibleMeal]);

      await service.setAvailability(visibleMeal.id, false);
      final adminMealsAfterHide = await service
          .watchAll(includeHidden: true)
          .first;
      final customerMealsAfterHide = await service.watchAvailable().first;
      expect(
        adminMealsAfterHide.meals.map((meal) => meal.id),
        contains(visibleMeal.id),
      );
      expect(
        adminMealsAfterHide.meals
            .singleWhere((meal) => meal.id == visibleMeal.id)
            .isAvailable,
        isFalse,
      );
      expect(customerMealsAfterHide.meals, isEmpty);

      await service.setAvailability(hiddenMeal.id, true);
      final restoredCustomerMeals = await service.watchAvailable().first;
      expect(restoredCustomerMeals.meals, hasLength(1));
      expect(
        restoredCustomerMeals.meals.map((meal) => meal.id),
        contains(hiddenMeal.id),
      );
      final restoredMeal = restoredCustomerMeals.meals.singleWhere(
        (meal) => meal.id == hiddenMeal.id,
      );
      expect(restoredMeal.isAvailable, isTrue);
      await service.dispose();
    },
  );

  test('admin search and visibility filters include hidden products', () {
    const visibleMeal = MealModel(
      id: 'visible',
      name: 'Garden Salad',
      category: MealCategory.starters,
      price: 4,
      imageUrl: '',
      description: 'Fresh greens',
    );
    const hiddenMeal = MealModel(
      id: 'hidden',
      name: 'Chocolate Cake',
      category: MealCategory.desserts,
      price: 6,
      imageUrl: '',
      description: 'Rich cocoa dessert',
      isAvailable: false,
    );
    final state = MenuManagementState(meals: [visibleMeal, hiddenMeal]);

    expect(state.visible, [visibleMeal, hiddenMeal]);
    expect(
      state.copyWith(visibilityFilter: MealVisibilityFilter.hidden).visible,
      [hiddenMeal],
    );
    expect(state.copyWith(searchQuery: 'cocoa').visible, [hiddenMeal]);
    expect(
      state
          .copyWith(
            searchQuery: 'cake',
            category: () => MealCategory.desserts,
            visibilityFilter: MealVisibilityFilter.hidden,
          )
          .visible,
      [hiddenMeal],
    );
    expect(
      state
          .copyWith(
            searchQuery: 'salad',
            visibilityFilter: MealVisibilityFilter.hidden,
          )
          .visible,
      isEmpty,
    );
  });

  testWidgets('admin visibility filters are centered under search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMenuRemoteService();
    final cubit = MenuManagementCubit(MenuRepository(service))..watch();
    await tester.pumpWidget(
      MaterialApp(
        home: MenuManagementScreen(
          repository: MenuRepository(service),
          existingCubit: cubit,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchRect = tester.getRect(
      find.byKey(const ValueKey('admin-product-search')),
    );
    final firstFilterRect = tester.getRect(
      find.byKey(const ValueKey('visibility-filter-all')),
    );
    final lastFilterRect = tester.getRect(
      find.byKey(const ValueKey('visibility-filter-hidden')),
    );
    final filtersCenter = (firstFilterRect.left + lastFilterRect.right) / 2;
    final categoryRect = tester.getRect(find.text('Starters'));
    expect(filtersCenter, closeTo(searchRect.center.dx, 1));
    expect(firstFilterRect.top, greaterThan(searchRect.bottom));
    expect(categoryRect.top, greaterThan(lastFilterRect.bottom));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 800);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
    await service.dispose();
  });

  testWidgets(
    'viewing products preserves the draft and saving stores its image URL',
    (tester) async {
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
        'Saved draft',
      );
      await tester.enterText(find.byKey(const ValueKey('meal-price')), '12.50');
      await tester.enterText(
        find.byKey(const ValueKey('meal-image-url')),
        'https://example.com/saved-draft.jpg',
      );
      await tester.tap(find.text('View saved products'));
      await tester.pumpAndSettle();

      expect(find.text('Customer Menu Products'), findsOneWidget);
      expect(service.meals, isEmpty);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Add New Meal'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('meal-name')))
            .controller!
            .text,
        'Saved draft',
      );
      await tester.tap(find.text('Save Meal'));
      await tester.pumpAndSettle();

      expect(
        service.meals.values.single.imageUrl,
        'https://example.com/saved-draft.jpg',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
      await service.dispose();
    },
  );

  test(
    'save reports a pending result when Firebase does not respond',
    () async {
      final service = _DelayedAddMenuRemoteService();
      final localCache = _InMemoryMealLocalCache();
      final cubit = MenuManagementCubit(
        MenuRepository(service, mealLocalCache: localCache),
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
      expect(localCache.snapshot?.meals, hasLength(1));
      expect(localCache.snapshot!.meals.single.name, meal.name);
      service.pendingAdd.complete();
      await cubit.close();
      await service.dispose();
    },
  );

  test('Firebase permission errors explain blocked cloud writes', () async {
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
          contains('Firebase rules denied access'),
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

  @override
  String newMealId() => 'test-meal-${_nextId++}';

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
  Stream<RemoteMealsSnapshot> watchAvailable() async* {
    yield RemoteMealsSnapshot(
      meals: meals.values.where((meal) => meal.isAvailable).toList(),
      isFromCache: _isFromCache,
      hasPendingWrites: false,
    );
    await for (final _ in _changes.stream) {
      yield RemoteMealsSnapshot(
        meals: meals.values.where((meal) => meal.isAvailable).toList(),
        isFromCache: _isFromCache,
        hasPendingWrites: false,
      );
    }
  }

  @override
  Stream<RemoteMealsSnapshot> watchAll({
    MealCategory? category,
    bool includeHidden = false,
  }) async* {
    yield RemoteMealsSnapshot(
      meals: _filtered(category: category)
          .where((meal) => includeHidden || meal.isAvailable)
          .toList(growable: false),
      isFromCache: _isFromCache,
      hasPendingWrites: false,
    );
    await for (final _ in _changes.stream) {
      yield RemoteMealsSnapshot(
        meals: _filtered(category: category)
            .where((meal) => includeHidden || meal.isAvailable)
            .toList(growable: false),
        isFromCache: _isFromCache,
        hasPendingWrites: false,
      );
    }
  }

  @override
  Future<void> add(MealModel meal) async {
    final id = meal.id.isEmpty ? newMealId() : meal.id;
    meals[id] = _withId(meal, id);
    _changes.add(null);
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

class _DelayedWriteMenuRemoteService extends _InMemoryMenuRemoteService {
  Completer<void> _pendingWrite = Completer<void>();

  void completePendingWrite() {
    _pendingWrite.complete();
    _pendingWrite = Completer<void>();
  }

  @override
  Future<void> update(MealModel meal) => _pendingWrite.future;

  @override
  Future<void> setAvailability(String id, bool value) => _pendingWrite.future;

  @override
  Future<void> delete(String id) => _pendingWrite.future;
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

  @override
  Future<void> replaceAvailableMeals(List<MealModel> meals) async {
    final cachedById = {
      for (final meal in snapshot?.meals ?? const <MealModel>[]) meal.id: meal,
    };
    final availableIds = meals.map((meal) => meal.id).toSet();
    cachedById.updateAll(
      (id, meal) => meal.isAvailable && !availableIds.contains(id)
          ? meal.copyWith(isAvailable: false)
          : meal,
    );
    for (final meal in meals) {
      cachedById[meal.id] = meal;
    }
    snapshot = CachedMeals(List.unmodifiable(cachedById.values));
  }

  @override
  Future<void> upsertMeal(MealModel meal) async {
    final meals = [...?snapshot?.meals];
    final index = meals.indexWhere((item) => item.id == meal.id);
    if (index == -1) {
      meals.add(meal);
    } else {
      meals[index] = meal;
    }
    snapshot = CachedMeals(List.unmodifiable(meals));
  }

  @override
  Future<void> removeMeal(String id) async {
    final meals = snapshot?.meals.where((meal) => meal.id != id).toList();
    if (meals != null) snapshot = CachedMeals(List.unmodifiable(meals));
  }
}

class _DelayedAddMenuRemoteService extends _InMemoryMenuRemoteService {
  final Completer<void> pendingAdd = Completer<void>();

  @override
  Future<void> add(MealModel meal) => pendingAdd.future;
}

class _DeniedAddMenuRemoteService extends _InMemoryMenuRemoteService {
  @override
  Future<void> add(MealModel meal) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

class _DeniedWatchMenuRemoteService extends _InMemoryMenuRemoteService {
  @override
  Stream<RemoteMealsSnapshot> watchAll({
    MealCategory? category,
    bool includeHidden = false,
  }) async* {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}
