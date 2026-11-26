import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';
import 'package:goodfood_ecosystem/features/menu/data/repositories/menu_repository.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/meal_local_cache.dart';
import 'package:goodfood_ecosystem/features/menu/data/services/menu_remote_service.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_cubit.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_state.dart';

const meal = MealModel(
  id: 'test-meal',
  name: 'Garden Salad',
  category: MealCategory.starters,
  price: 8.5,
  imageUrl: '',
  description: 'Fresh vegetables',
);

class BrokenOutbox implements MealLocalCache, MealMutationOutbox {
  @override
  Future<CachedMeals?> readMeals() async =>
      throw UnsupportedError('SQLite unavailable');
  @override
  Future<void> replaceAvailableMeals(List<MealModel> meals) async =>
      throw UnsupportedError('SQLite unavailable');
  @override
  Future<List<PendingMealMutation>> readPendingMutations() async =>
      throw UnsupportedError('SQLite unavailable');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RetryRemote implements MenuRemoteService {
  var attempts = 0;
  @override
  Stream<RemoteMealsSnapshot> watchAvailable() async* {
    if (++attempts == 1) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    yield const RemoteMealsSnapshot(
      meals: [meal],
      isFromCache: false,
      hasPendingWrites: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixedRemote implements MenuRemoteService {
  @override
  Stream<RemoteMealsSnapshot> watchAvailable() => Stream.value(
    const RemoteMealsSnapshot(
      meals: [meal],
      isFromCache: false,
      hasPendingWrites: false,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a broken SQLite outbox cannot discard valid Firestore meals', () async {
    final repo = MenuRepository(FixedRemote(), mealLocalCache: BrokenOutbox());
    final result = await repo.watchAvailableMeals().first.timeout(
      const Duration(seconds: 3),
    );
    expect(result.isFromCache, isFalse);
    expect(result.meals.single.name, meal.name);
    expect(result.meals.single.price, 8.5);
  });

  test(
    'retry reconnects after failure and filters do not hide errors',
    () async {
      final remote = RetryRemote();
      final cubit = MenuCubit(MenuRepository(remote));
      addTearDown(cubit.close);
      final failed = cubit.stream.firstWhere(
        (s) => s.status == MenuStatus.failure,
      );
      await cubit.load();
      await failed;
      expect(cubit.state.error, contains('Menu access was denied'));
      cubit.selectCategory(MealCategory.starters);
      expect(cubit.state.status, MenuStatus.failure);
      final recovered = cubit.stream.firstWhere(
        (s) => s.status == MenuStatus.success,
      );
      await cubit.load();
      await recovered;
      expect(remote.attempts, 2);
      expect(cubit.state.meals.single.id, meal.id);
      expect(cubit.state.error, isNull);
    },
  );
}
