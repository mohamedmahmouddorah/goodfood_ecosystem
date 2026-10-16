import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:goodfood_ecosystem/features/cart/data/services/cart_local_storage.dart';
import 'package:goodfood_ecosystem/features/cart/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/cart/presentation/view_model/cart_state.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';

void main() {
  test(
    'cart persists and restores from SQLite across storage instances',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final directory = await Directory.systemTemp.createTemp('goodfood-cart-');
      final databasePath = p.join(directory.path, 'cart.db');
      final firstStorage = SqliteCartLocalStorage(databasePath: databasePath);
      const meal = MealModel(
        id: 'meal-1',
        name: 'Grilled Chicken',
        category: MealCategory.mainCourse,
        price: 12.99,
        imageUrl: 'https://example.com/meal.png',
        description: 'Grilled with herbs',
        isAvailable: true,
      );

      try {
        final cubit = CartCubit(storage: firstStorage);
        await cubit.initialized;
        cubit.add(meal);
        cubit.increase(meal.id);
        await cubit.persistenceComplete;
        expect(cubit.state.items.single.quantity, 2);
        await cubit.close();
        await firstStorage.close();

        final secondStorage = SqliteCartLocalStorage(
          databasePath: databasePath,
        );
        final restoredCubit = CartCubit(storage: secondStorage);
        await restoredCubit.initialized;

        expect(restoredCubit.state.items, hasLength(1));
        final restored = restoredCubit.state.items.single;
        expect(restored.quantity, 2);
        expect(restored.meal.id, meal.id);
        expect(restored.meal.name, meal.name);
        expect(restored.meal.category, meal.category);
        expect(restored.meal.price, meal.price);
        expect(restored.meal.imageUrl, meal.imageUrl);
        expect(restored.meal.description, meal.description);
        expect(restored.meal.isAvailable, meal.isAvailable);

        restoredCubit.clear();
        await restoredCubit.persistenceComplete;
        await restoredCubit.close();
        expect(await secondStorage.readItems(), isEmpty);
        await secondStorage.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'cart changes made while SQLite is loading are not overwritten',
    () async {
      final storage = _DelayedCartStorage();
      final cubit = CartCubit(storage: storage);
      const meal = MealModel(
        id: 'meal-2',
        name: 'Added during startup',
        category: MealCategory.starters,
        price: 4,
        imageUrl: '',
      );

      cubit.add(meal);
      storage.completeRead(const []);
      await cubit.initialized;
      await cubit.persistenceComplete;

      expect(cubit.state.items.single.meal.id, meal.id);
      expect(storage.savedItems.single.meal.id, meal.id);
      await cubit.close();
    },
  );

  test('menu sync during SQLite load is applied to restored cart', () async {
    const meal = MealModel(
      id: 'meal-hidden-while-app-was-closed',
      name: 'Hidden meal',
      category: MealCategory.mainCourse,
      price: 8,
      imageUrl: '',
    );
    final storage = _DelayedCartStorage();
    final cubit = CartCubit(storage: storage);

    cubit.syncAvailableMeals(const []);
    storage.completeRead(const [CartItem(meal: meal, quantity: 2)]);
    await cubit.initialized;
    await cubit.persistenceComplete;

    expect(cubit.state.items.single.meal.isAvailable, isFalse);
    expect(storage.savedItems.single.meal.isAvailable, isFalse);
    expect(cubit.state.total, 0);
    await cubit.close();
  });

  test('rapid cart updates are coalesced while SQLite is writing', () async {
    final storage = _SlowWriteCartStorage();
    final cubit = CartCubit(storage: storage);
    const meal = MealModel(
      id: 'meal-3',
      name: 'Repeated addition',
      category: MealCategory.desserts,
      price: 3,
      imageUrl: '',
    );

    await cubit.initialized;
    cubit.add(meal);
    await storage.firstWriteStarted.future;

    for (var i = 0; i < 20; i++) {
      cubit.add(meal);
    }

    storage.finishFirstWrite.complete();
    await cubit.persistenceComplete;

    expect(storage.writes, 2);
    expect(storage.savedItems.single.quantity, 21);
    expect(cubit.state.items.single.quantity, 21);
    await cubit.close();
  });
}

class _DelayedCartStorage implements CartLocalStorage {
  final readCompleter = Completer<List<CartItem>>();
  List<CartItem> savedItems = const [];

  @override
  Future<List<CartItem>> readItems() => readCompleter.future;

  void completeRead(List<CartItem> items) => readCompleter.complete(items);

  @override
  Future<void> replaceItems(List<CartItem> items) async {
    savedItems = List<CartItem>.of(items);
  }
}

class _SlowWriteCartStorage implements CartLocalStorage {
  final firstWriteStarted = Completer<void>();
  final finishFirstWrite = Completer<void>();
  int writes = 0;
  List<CartItem> savedItems = const [];

  @override
  Future<List<CartItem>> readItems() async => const [];

  @override
  Future<void> replaceItems(List<CartItem> items) async {
    writes++;
    if (writes == 1) {
      firstWriteStarted.complete();
      await finishFirstWrite.future;
    }
    savedItems = List<CartItem>.of(items);
  }
}
