import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal_model.dart';

class RemoteMealsSnapshot {
  const RemoteMealsSnapshot({
    required this.meals,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final List<MealModel> meals;
  final bool isFromCache;
  final bool hasPendingWrites;
}

/// Only class that talks to Firestore for the menu feature.
class MenuRemoteService {
  MenuRemoteService(FirebaseFirestore db) : _meals = db.collection('meals');

  final CollectionReference<Map<String, dynamic>> _meals;

  // ───────────── Customer ─────────────
  Future<MealModel?> fetchMeal(String id) async {
    final doc = await _meals.doc(id).get();
    return doc.exists ? MealModel.fromDoc(doc) : null;
  }

  // ───────────── Admin ─────────────

  /// Live customer list. Only available products are returned.
  Stream<RemoteMealsSnapshot> watchAvailable() =>
      _watch(_meals.where('isAvailable', isEqualTo: true));

  /// Requests all meals for the management screen. Firestore rules remain the
  /// authority on whether this client can read hidden products.
  Stream<RemoteMealsSnapshot> watchAll({
    MealCategory? category,
    bool includeHidden = false,
  }) {
    Query<Map<String, dynamic>> query = _meals;
    if (!includeHidden) {
      query = query.where('isAvailable', isEqualTo: true);
    }
    if (category != null) {
      query = query.where('category', isEqualTo: category.key);
    }
    return _watch(query);
  }

  Stream<RemoteMealsSnapshot> _watch(Query<Map<String, dynamic>> query) {
    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      final meals = snapshot.docs.map(MealModel.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return RemoteMealsSnapshot(
        meals: meals,
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    });
  }

  String newMealId() => _meals.doc().id;

  Future<void> add(MealModel meal) async {
    await _meals.doc(meal.id).set({
      ...meal.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(MealModel meal) =>
      _meals.doc(meal.id).update(meal.toMap());

  /// Single-field write: cheapest operation for the visibility switch.
  Future<void> setAvailability(String id, bool value) =>
      _meals.doc(id).update({'isAvailable': value});

  Future<void> delete(String id) => _meals.doc(id).delete();
}
