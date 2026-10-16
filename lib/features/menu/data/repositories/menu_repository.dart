import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/meal_model.dart';
import '../services/meal_local_cache.dart';
import '../services/menu_remote_service.dart';

class MenuFailure implements Exception {
  const MenuFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The Cubit talks to this class only. It never sees Firestore errors.
class MenuRepository {
  MenuRepository(this._service, {MealLocalCache? mealLocalCache})
    : _mealLocalCache = mealLocalCache;

  final MenuRemoteService _service;
  final MealLocalCache? _mealLocalCache;

  Future<MealModel?> getMeal(String id) => _guard(() => _service.fetchMeal(id));

  Stream<RemoteMealsSnapshot> watchAvailableMeals() async* {
    try {
      final cachedMeals = await _readCachedMeals();
      if (cachedMeals != null) {
        yield RemoteMealsSnapshot(
          meals: cachedMeals.meals.where((meal) => meal.isAvailable).toList(),
          isFromCache: true,
          hasPendingWrites: false,
        );
      }

      final cache = _mealLocalCache;
      await for (final snapshot in _service.watchAvailable()) {
        if (!snapshot.isFromCache &&
            !snapshot.hasPendingWrites &&
            cache != null) {
          await _writeLocal(() => cache.replaceAvailableMeals(snapshot.meals));
        }
        yield snapshot;
      }
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  Stream<List<MealModel>> watchAllMeals({MealCategory? category}) async* {
    try {
      final cachedMeals = await _readCachedMeals();
      if (cachedMeals != null) yield cachedMeals.meals;

      final cache = _mealLocalCache;
      await for (final snapshot in _service.watchAll(
        category: category,
        includeHidden: true,
      )) {
        if (!snapshot.isFromCache &&
            !snapshot.hasPendingWrites &&
            cache != null) {
          await _writeLocal(() => cache.replaceMeals(snapshot.meals));
        }
        yield snapshot.meals;
      }
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  Future<String> addMeal(MealModel meal) async {
    final id = meal.id.isEmpty ? _service.newMealId() : meal.id;
    final localMeal = meal.copyWith(id: id);
    await _writeLocal(
      () => _mealLocalCache?.upsertMeal(localMeal) ?? Future<void>.value(),
    );
    try {
      await _guard(() => _service.add(localMeal));
      return id;
    } on MenuFailure {
      await _writeLocal(
        () => _mealLocalCache?.removeMeal(id) ?? Future<void>.value(),
      );
      rethrow;
    }
  }

  Future<void> updateMeal(MealModel meal) async {
    final previous = await _cachedMeal(meal.id);
    await _writeLocal(
      () => _mealLocalCache?.upsertMeal(meal) ?? Future<void>.value(),
    );
    try {
      await _guard(() => _service.update(meal));
    } on MenuFailure {
      await _restoreCachedMeal(meal.id, previous);
      rethrow;
    }
  }

  Future<void> setAvailability(String id, bool value, {MealModel? meal}) async {
    final previous = await _cachedMeal(id) ?? meal;
    if (previous != null) {
      await _writeLocal(
        () =>
            _mealLocalCache?.upsertMeal(
              previous.copyWith(isAvailable: value),
            ) ??
            Future<void>.value(),
      );
    }
    try {
      await _guard(() => _service.setAvailability(id, value));
    } on MenuFailure {
      await _restoreCachedMeal(id, previous);
      rethrow;
    }
  }

  Future<void> deleteMeal(String id, {MealModel? meal}) async {
    final previous = await _cachedMeal(id) ?? meal;
    await _writeLocal(
      () => _mealLocalCache?.removeMeal(id) ?? Future<void>.value(),
    );
    try {
      await _guard(() => _service.delete(id));
    } on MenuFailure {
      await _restoreCachedMeal(id, previous);
      rethrow;
    }
  }

  Future<MealModel?> _cachedMeal(String id) async {
    final cachedMeals = await _readCachedMeals();
    for (final meal in cachedMeals?.meals ?? const <MealModel>[]) {
      if (meal.id == id) return meal;
    }
    return null;
  }

  Future<void> _restoreCachedMeal(String id, MealModel? meal) async {
    if (meal == null) {
      await _writeLocal(
        () => _mealLocalCache?.removeMeal(id) ?? Future<void>.value(),
      );
    } else {
      await _writeLocal(
        () => _mealLocalCache?.upsertMeal(meal) ?? Future<void>.value(),
      );
    }
  }

  Future<CachedMeals?> _readCachedMeals() async {
    final cache = _mealLocalCache;
    if (cache == null) return null;
    return _runLocal(() => cache.readMeals());
  }

  Future<void> _writeLocal(Future<void> Function() write) => _runLocal(write);

  Future<T> _runLocal<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on Exception catch (error, stackTrace) {
      debugPrint('Menu local cache operation failed: $error\n$stackTrace');
      throw const MenuFailure(
        'Could not access local menu storage. Check device storage and try again.',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  String _firebaseMessage(FirebaseException error) => switch (error.code) {
    'permission-denied' =>
      'Firebase rules denied access. Allow the admin app to read hidden products and update their availability in Firestore rules.',
    'unauthenticated' =>
      'Firebase requires an authorized account to save changes.',
    'unavailable' =>
      'No internet connection. Connect to download the menu and sync changes.',
    'failed-precondition' =>
      'The Firebase menu index is not ready. Deploy the indexes and try again.',
    'not-found' => 'Meal not found.',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };
}
