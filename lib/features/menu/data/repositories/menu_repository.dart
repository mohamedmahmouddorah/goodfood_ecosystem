import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal_model.dart';
import '../services/meal_local_cache.dart';
import '../services/menu_remote_service.dart';
import '../services/menu_api_service.dart';

class MenuFailure implements Exception {
  const MenuFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The Cubit talks to this class only. It never sees Firestore errors.
class MenuRepository {
  MenuRepository(
    this._service, {
    MenuApiService? menuApiService,
    MealLocalCache? mealLocalCache,
  }) : _menuApiService = menuApiService,
       _mealLocalCache = mealLocalCache;

  final MenuRemoteService _service;
  final MenuApiService? _menuApiService;
  final MealLocalCache? _mealLocalCache;

  Future<MealsPage> getMeals({
    MealCategory? category,
    String query = '',
    MealDoc? after,
  }) {
    final menuApiService = _menuApiService;
    if (menuApiService != null) {
      return _guard(
        () => menuApiService.fetchMeals(category: category, query: query),
      );
    }
    return _guard(
      () => _service.fetchPage(
        category: category,
        query: query,
        after: after,
      ),
    );
  }

  Future<MealModel?> getMeal(String id) => _guard(() => _service.fetchMeal(id));

  Stream<List<MealModel>> watchAllMeals({MealCategory? category}) async* {
    try {
      final cachedMeals = await _mealLocalCache?.readMeals();
      if (cachedMeals != null) yield cachedMeals.meals;

      await for (final snapshot in _service.watchAll(category: category)) {
        if (snapshot.isFromCache) {
          if (cachedMeals == null && snapshot.meals.isNotEmpty) {
            yield snapshot.meals;
          }
          continue;
        }
        if (!snapshot.hasPendingWrites) {
          await _mealLocalCache?.replaceMeals(snapshot.meals);
        }
        yield snapshot.meals;
      }
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  Future<String> addMeal(MealModel meal) => _guard(() => _service.add(meal));
  Future<void> updateMeal(MealModel meal) => _guard(() => _service.update(meal));
  Future<void> setAvailability(String id, bool value) =>
      _guard(() => _service.setAvailability(id, value));
  Future<void> deleteMeal(String id) => _guard(() => _service.delete(id));

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on MenuApiException catch (e) {
      throw MenuFailure(e.message);
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  String _firebaseMessage(FirebaseException error) => switch (error.code) {
    'permission-denied' =>
      'Admin access is not configured. Sign in with an admin Firebase account.',
        'unauthenticated' =>
          'Sign in with an admin Firebase account before saving meals.',
        'unavailable' => 'No connection. Please try again.',
        'not-found' => 'Meal not found.',
        _ => error.message ?? 'Something went wrong. Please try again.',
      };
}