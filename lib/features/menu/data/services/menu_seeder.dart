import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/meal_model.dart';

/// ONE-TIME tool (debug only). Fills the `meals` collection from
/// TheMealDB (food) + TheCocktailDB (non-alcoholic drinks).
/// Doc ids are deterministic, so running it twice does not duplicate data.
///
/// Neither API has prices or an availability flag, so we add them here.
/// Usage (e.g. from a temporary debug button):
///   await MenuSeeder(FirebaseFirestore.instance).run();
class MenuSeeder {
  MenuSeeder(this._db, [http.Client? client]) : _http = client ?? http.Client();

  final FirebaseFirestore _db;
  final http.Client _http;

  static const _mealApi = 'https://www.themealdb.com/api/json/v1/1';
  static const _drinkApi = 'https://www.thecocktaildb.com/api/json/v1/1';

  Future<void> run({int perCategory = 10}) async {
    final buckets = {for (final c in MealCategory.values) c: <MealModel>[]};
    final ids = <String>[];

    // search.php?f=<letter> returns FULL meals (name, category, area, image),
    // so 26 parallel calls replace hundreds of lookup calls.
    final pages = await Future.wait(
      'abcdefghijklmnopqrstuvwxyz'.split('').map((l) => _get('$_mealApi/search.php?f=$l')),
    );
    for (final page in pages) {
      for (final m in (page['meals'] as List? ?? const [])) {
        final category = _mapCategory(m['strCategory'] as String?);
        if (category == null || buckets[category]!.length >= perCategory) continue;
        final id = m['idMeal'] as String;
        buckets[category]!.add(MealModel(
          id: id,
          name: m['strMeal'] as String,
          category: category,
          price: _price(id, base: category == MealCategory.mainCourse ? 8 : 4),
          imageUrl: m['strMealThumb'] as String,
          description: '${m['strArea']} ${(m['strCategory'] as String).toLowerCase()} dish.',
        ));
        ids.add(id);
      }
    }

    final drinks = await _get('$_drinkApi/filter.php?a=Non_Alcoholic');
    for (final d in (drinks['drinks'] as List? ?? const []).take(perCategory)) {
      final id = 'd_${d['idDrink']}';
      buckets[MealCategory.drinks]!.add(MealModel(
        id: id,
        name: d['strDrink'] as String,
        category: MealCategory.drinks,
        price: _price(d['idDrink'] as String, base: 2),
        imageUrl: d['strDrinkThumb'] as String,
        description: 'Refreshing non-alcoholic drink.',
      ));
    }

    final batch = _db.batch(); // max 500 writes; we write ~40
    for (final meal in buckets.values.expand((e) => e)) {
      batch.set(_db.collection('meals').doc(meal.id), {
        ...meal.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  MealCategory? _mapCategory(String? c) => switch (c) {
        'Starter' || 'Side' => MealCategory.starters,
        'Dessert' => MealCategory.desserts,
        'Breakfast' || null => null,
        _ => MealCategory.mainCourse,
      };

  /// Stable fake price from the API id: e.g. 8.99 … 20.99
  double _price(String id, {required int base}) =>
      base + ((int.tryParse(id) ?? 0) % 13) + 0.99;

  Future<Map<String, dynamic>> _get(String url) async {
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('API error ${res.statusCode}: $url');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}