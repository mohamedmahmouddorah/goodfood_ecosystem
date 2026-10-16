import 'package:flutter/foundation.dart' show ValueGetter;

import '../../data/models/meal_model.dart';

enum ManagementStatus { loading, success, failure }

enum MealVisibilityFilter { all, visible, hidden }

class MenuManagementState {
  const MenuManagementState({
    this.status = ManagementStatus.loading,
    this.meals = const [],
    this.category,
    this.searchQuery = '',
    this.visibilityFilter = MealVisibilityFilter.all,
    this.message,
    this.loadError,
  });

  final ManagementStatus status;
  final List<MealModel> meals; // ALL meals, including hidden ones
  final MealCategory? category; // null = All
  final String searchQuery;
  final MealVisibilityFilter visibilityFilter;
  final String? message; // one-shot snackbar text
  final String? loadError;

  /// Admin filters run locally over the complete list, including hidden meals.
  List<MealModel> get visible {
    final query = searchQuery.trim().toLowerCase();
    return meals
        .where((meal) {
          final matchesCategory = category == null || meal.category == category;
          final matchesVisibility = switch (visibilityFilter) {
            MealVisibilityFilter.all => true,
            MealVisibilityFilter.visible => meal.isAvailable,
            MealVisibilityFilter.hidden => !meal.isAvailable,
          };
          final matchesQuery =
              query.isEmpty ||
              meal.name.toLowerCase().contains(query) ||
              meal.description.toLowerCase().contains(query) ||
              meal.category.label.toLowerCase().contains(query);
          return matchesCategory && matchesVisibility && matchesQuery;
        })
        .toList(growable: false);
  }

  MenuManagementState copyWith({
    ManagementStatus? status,
    List<MealModel>? meals,
    ValueGetter<MealCategory?>? category,
    String? searchQuery,
    MealVisibilityFilter? visibilityFilter,
    ValueGetter<String?>? message,
    ValueGetter<String?>? loadError,
  }) => MenuManagementState(
    status: status ?? this.status,
    meals: meals ?? this.meals,
    category: category != null ? category() : this.category,
    searchQuery: searchQuery ?? this.searchQuery,
    visibilityFilter: visibilityFilter ?? this.visibilityFilter,
    message: message != null ? message() : this.message,
    loadError: loadError != null ? loadError() : this.loadError,
  );
}
