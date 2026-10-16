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
    : _cache = mealLocalCache;

  final MenuRemoteService _service;
  final MealLocalCache? _cache;

  // ───────────── Streams (the cache here is best-effort) ─────────────

  Stream<RemoteMealsSnapshot> watchAvailableMeals() async* {
    try {
      final cached = await _readCacheSafely();
      if (cached != null) {
        yield RemoteMealsSnapshot(
          meals: cached.meals
              .where((meal) => meal.isAvailable)
              .toList(growable: false),
          isFromCache: true,
          hasPendingWrites: false,
        );
      }
      await for (final snapshot in _service.watchAvailable()) {
        yield snapshot;
        if (_shouldPersist(snapshot)) {
          await _writeCacheSafely(
            (cache) => cache.replaceAvailableMeals(snapshot.meals),
          );
        }
      }
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  Stream<List<MealModel>> watchAllMeals() async* {
    try {
      final cached = await _readCacheSafely();
      if (cached != null) yield cached.meals;
      await for (final snapshot in _service.watchAll(includeHidden: true)) {
        yield snapshot.meals;
        if (_shouldPersist(snapshot)) {
          await _writeCacheSafely(
            (cache) => cache.replaceMeals(snapshot.meals),
          );
        }
      }
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  // ───────────── Mutations (local first, rollback on failure) ─────────────

  Future<String> addMeal(MealModel meal) async {
    final id = meal.id.isEmpty ? _service.newMealId() : meal.id;
    final localMeal = meal.copyWith(id: id);
    await _local((cache) => cache.upsertMeal(localMeal));
    try {
      await _guard(() => _service.add(localMeal));
      return id;
    } on MenuFailure {
      await _local((cache) => cache.removeMeal(id));
      rethrow;
    }
  }

  Future<void> updateMeal(MealModel meal) async {
    final previous = await _cachedMeal(meal.id);
    await _local((cache) => cache.upsertMeal(meal));
    try {
      await _guard(() => _service.update(meal));
    } on MenuFailure {
      await _restore(meal.id, previous);
      rethrow;
    }
  }

  Future<void> setAvailability(String id, bool value, {MealModel? meal}) async {
    final previous = await _cachedMeal(id) ?? meal;
    if (previous != null) {
      await _local(
        (cache) => cache.upsertMeal(previous.copyWith(isAvailable: value)),
      );
    }
    try {
      await _guard(() => _service.setAvailability(id, value));
    } on MenuFailure {
      await _restore(id, previous);
      rethrow;
    }
  }

  Future<void> deleteMeal(String id, {MealModel? meal}) async {
    final previous = await _cachedMeal(id) ?? meal;
    await _local((cache) => cache.removeMeal(id));
    try {
      await _guard(() => _service.delete(id));
    } on MenuFailure {
      await _restore(id, previous);
      rethrow;
    }
  }

  // ───────────── Cache helpers ─────────────

  bool _shouldPersist(RemoteMealsSnapshot s) =>
      _cache != null && !s.isFromCache && !s.hasPendingWrites;

  Future<CachedMeals?> _readCacheSafely() async {
    final cache = _cache;
    if (cache == null) return null;
    try {
      return await cache.readMeals();
    } catch (error, stackTrace) {
      debugPrint('Menu cache read failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> _writeCacheSafely(
    Future<void> Function(MealLocalCache cache) write,
  ) async {
    final cache = _cache;
    if (cache == null) return;
    try {
      await write(cache);
    } catch (error, stackTrace) {
      debugPrint('Menu cache write failed: $error\n$stackTrace');
    }
  }

  /// For mutations: a local failure is reported to the user.
  Future<T?> _local<T>(Future<T> Function(MealLocalCache cache) operation) async {
    final cache = _cache;
    if (cache == null) return null;
    try {
      return await operation(cache);
    } on Exception catch (error, stackTrace) {
      debugPrint('Menu local cache operation failed: $error\n$stackTrace');
      throw const MenuFailure(
        'Could not access local menu storage. Check device storage and try again.',
      );
    }
  }

  Future<MealModel?> _cachedMeal(String id) =>
      _local<MealModel?>((cache) => cache.readMeal(id));

  Future<void> _restore(String id, MealModel? meal) async {
    await _local(
      (cache) => meal == null ? cache.removeMeal(id) : cache.upsertMeal(meal),
    );
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