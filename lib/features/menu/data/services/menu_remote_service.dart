import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal_model.dart';

typedef MealDoc = DocumentSnapshot<Map<String, dynamic>>;

class MealsPage {
  const MealsPage({required this.meals, required this.cursor, required this.hasMore});
  final List<MealModel> meals;
  final MealDoc? cursor; // pass back as `after` to load the next page
  final bool hasMore;
}

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

  static const pageSize = 20;
  final CollectionReference<Map<String, dynamic>> _meals;

  // ───────────── Customer ─────────────

  /// Visible meals only, optional category, optional prefix search.
  /// Always ordered by `nameLower` so one composite index covers every case:
  ///   meals: isAvailable ASC, category ASC, nameLower ASC
  Future<MealsPage> fetchPage({
    MealCategory? category,
    String query = '',
    MealDoc? after,
  }) async {
    Query<Map<String, dynamic>> q = _meals.where('isAvailable', isEqualTo: true);
    if (category != null) q = q.where('category', isEqualTo: category.key);

    final s = query.trim().toLowerCase();
    if (s.isNotEmpty) {
      q = q
          .where('nameLower', isGreaterThanOrEqualTo: s)
          .where('nameLower', isLessThan: '$s\uf8ff');
    }
    q = q.orderBy('nameLower').limit(pageSize);
    if (after != null) q = q.startAfterDocument(after);

    final snap = await q.get();
    return MealsPage(
      meals: snap.docs.map(MealModel.fromDoc).toList(growable: false),
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == pageSize,
    );
  }

  Future<MealModel?> fetchMeal(String id) async {
    final doc = await _meals.doc(id).get();
    return doc.exists ? MealModel.fromDoc(doc) : null;
  }

  // ───────────── Admin ─────────────

  /// Live list for Menu Management (includes hidden meals).
  /// Only changed documents are billed on updates, not the whole list.
  Stream<RemoteMealsSnapshot> watchAll({MealCategory? category}) {
    Query<Map<String, dynamic>> q = _meals;
    if (category != null) q = q.where('category', isEqualTo: category.key);
    return q.snapshots(includeMetadataChanges: true).map((snapshot) {
      final meals = snapshot.docs.map(MealModel.fromDoc).toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      return RemoteMealsSnapshot(
        meals: meals,
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    });
  }

  Future<String> add(MealModel meal) async {
    final ref = await _meals.add({
      ...meal.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(MealModel meal) => _meals.doc(meal.id).update(meal.toMap());

  /// Single-field write: cheapest operation for the visibility switch.
  Future<void> setAvailability(String id, bool value) =>
      _meals.doc(id).update({'isAvailable': value});

  Future<void> delete(String id) => _meals.doc(id).delete();
}