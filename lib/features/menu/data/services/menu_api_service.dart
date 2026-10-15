import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/meal_model.dart';
import 'menu_remote_service.dart' show MealsPage;

class MenuApiException implements Exception {
  const MenuApiException(this.message);

  final String message;
}

class MenuApiService {
  MenuApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _mealDbHost = 'www.themealdb.com';
  static const _cocktailDbHost = 'www.thecocktaildb.com';
  static const _apiPath = '/api/json/v1/1';

  final http.Client _client;
  List<MealModel>? _cachedMeals;

  Future<MealsPage> fetchMeals({
    MealCategory? category,
    String query = '',
  }) async {
    final trimmedQuery = query.trim();
    final allMeals = trimmedQuery.isEmpty
        ? await _fetchAllMeals()
        : await _fetchByName(trimmedQuery);
    final visibleMeals = allMeals
        .where((meal) => category == null || meal.category == category)
        .toList(growable: false);

    return MealsPage(
      meals: visibleMeals,
      cursor: null,
      hasMore: false,
    );
  }

  Future<List<MealModel>> _fetchAllMeals() async {
    final cachedMeals = _cachedMeals;
    if (cachedMeals != null) return cachedMeals;

    try {
      final responses = await Future.wait(
        [
          ...'abcdefghijklmnopqrstuvwxyz'.split('').map(
                (letter) => _get(
                  _mealDbHost,
                  '/search.php',
                  {'f': letter},
                ),
              ),
          _get(
            _cocktailDbHost,
            '/filter.php',
            {'a': 'Non_Alcoholic'},
          ),
        ],
      );
      final mealsById = <String, MealModel>{};
      for (final response in responses.take(26)) {
        for (final meal in _parseMeals(response)) {
          mealsById[meal.id] = meal;
        }
      }
      for (final drink in _parseDrinks(responses.last)) {
        mealsById[drink.id] = drink;
      }
      _cachedMeals = mealsById.values.toList(growable: false);
      return _cachedMeals!;
    } on TimeoutException {
      throw const MenuApiException(
        'The meal service took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const MenuApiException(
        'Could not connect to the meal service. Check your internet connection.',
      );
    } on FormatException {
      throw const MenuApiException(
        'The meal service returned invalid data. Please try again later.',
      );
    }
  }

  Future<List<MealModel>> _fetchByName(String query) async {
    try {
      final responses = await Future.wait([
        _get(_mealDbHost, '/search.php', {'s': query}),
        _get(_cocktailDbHost, '/search.php', {'s': query}),
      ]);
      return [
        ..._parseMeals(responses.first),
        ..._parseDrinks(responses.last),
      ];
    } on TimeoutException {
      throw const MenuApiException(
        'The meal service took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const MenuApiException(
        'Could not connect to the meal service. Check your internet connection.',
      );
    } on FormatException {
      throw const MenuApiException(
        'The meal service returned invalid data. Please try again later.',
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    String host,
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(host, '$_apiPath$path', query);
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw MenuApiException(
        'The meal service returned status ${response.statusCode}. Please try again.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  List<MealModel> _parseMeals(Map<String, dynamic> response) {
    final rawMeals = response['meals'];
    if (rawMeals == null) return const [];
    if (rawMeals is! List) {
      throw const FormatException('Expected a meals list.');
    }

    return rawMeals.map((rawMeal) {
      if (rawMeal is! Map<String, dynamic>) {
        throw const FormatException('Expected a meal object.');
      }
      final id = rawMeal['idMeal'];
      final name = rawMeal['strMeal'];
      final imageUrl = rawMeal['strMealThumb'];
      if (id is! String || name is! String || imageUrl is! String) {
        throw const FormatException('Meal is missing required fields.');
      }

      final rawCategory = rawMeal['strCategory'];
      if (rawCategory != null && rawCategory is! String) {
        throw const FormatException('Meal category is invalid.');
      }
      final category = _mapCategory(rawCategory as String?);
      final rawDescription = rawMeal['strInstructions'];
      if (rawDescription != null && rawDescription is! String) {
        throw const FormatException('Meal description is invalid.');
      }
      return MealModel(
        id: id,
        name: name,
        category: category,
        price: _estimatedPrice(id, category),
        imageUrl: imageUrl,
        description: rawDescription as String? ?? '',
      );
    }).toList(growable: false);
  }

  List<MealModel> _parseDrinks(Map<String, dynamic> response) {
    final rawDrinks = response['drinks'];
    if (rawDrinks == null) return const [];
    if (rawDrinks is! List) {
      throw const FormatException('Expected a drinks list.');
    }

    return rawDrinks.map((rawDrink) {
      if (rawDrink is! Map<String, dynamic>) {
        throw const FormatException('Expected a drink object.');
      }
      final id = rawDrink['idDrink'];
      final name = rawDrink['strDrink'];
      final imageUrl = rawDrink['strDrinkThumb'];
      if (id is! String || name is! String || imageUrl is! String) {
        throw const FormatException('Drink is missing required fields.');
      }

      final rawDescription = rawDrink['strInstructions'];
      if (rawDescription != null && rawDescription is! String) {
        throw const FormatException('Drink description is invalid.');
      }
      return MealModel(
        id: 'd_$id',
        name: name,
        category: MealCategory.drinks,
        price: _estimatedPrice(id, MealCategory.drinks),
        imageUrl: imageUrl,
        description:
            rawDescription as String? ?? 'Refreshing non-alcoholic drink.',
      );
    }).toList(growable: false);
  }

  MealCategory _mapCategory(String? category) => switch (category) {
        'Starter' || 'Side' => MealCategory.starters,
        'Dessert' => MealCategory.desserts,
        _ => MealCategory.mainCourse,
      };

  double _estimatedPrice(String id, MealCategory category) {
    final idValue = int.tryParse(id) ??
        id.codeUnits.fold<int>(0, (value, unit) => value + unit);
    final (base, range) = switch (category) {
      MealCategory.starters => (4, 7),
      MealCategory.desserts => (3, 7),
      MealCategory.drinks => (2, 5),
      MealCategory.mainCourse => (9, 12),
    };
    return base + (idValue % range) + 0.99;
  }
}
