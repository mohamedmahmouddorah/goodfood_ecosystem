import 'package:flutter/foundation.dart' show ValueGetter;

import '../../data/models/meal_model.dart';

enum ManagementStatus { loading, success, failure }
enum MealVisibilityFilter { all, visible, hidden }

extension MealVisibilityFilterX on MealVisibilityFilter {
  bool matches(MealModel meal) => switch (this) {
    MealVisibilityFilter.all => true,
    MealVisibilityFilter.visible => meal.isAvailable,
    MealVisibilityFilter.hidden => !meal.isAvailable,
  };
}

class MenuManagementState {  MenuManagementState({
    this.status = ManagementStatus.loading,
    List<MealModel>? meals,
    List<MealModel>? visible,
    this.category,
    this.searchQuery = '',
    this.visibilityFilter = MealVisibilityFilter.all,
    this.message,
    this.loadError,
  }) : meals = meals ?? const [],
       visible = visible ?? _filterMeals(
         meals ?? const [],
         category,
         searchQuery,
         visibilityFilter,
       );

  final ManagementStatus status;
  final List<MealModel> meals; // ALL meals, including hidden ones
  final List<MealModel> visible; // filtered once in the Cubit
  final MealCategory? category; // null = All
  final String searchQuery;
  final MealVisibilityFilter visibilityFilter;
  final String? message; // one-shot snackbar text
  final String? loadError;

  static List<MealModel> _filterMeals(
    List<MealModel> meals,
    MealCategory? category,
    String searchQuery,
    MealVisibilityFilter visibilityFilter,
  ) {
    final query = searchQuery.trim().toLowerCase();
    return [
      for (final meal in meals)
        if ((category == null || meal.category == category) &&
            visibilityFilter.matches(meal) &&
            (query.isEmpty || meal.name.toLowerCase().contains(query) ||
                meal.description.toLowerCase().contains(query) ||
                meal.category.label.toLowerCase().contains(query)))
          meal,
    ];
  }

  MenuManagementState copyWith({
    ManagementStatus? status,
    List<MealModel>? meals,
    List<MealModel>? visible,
    ValueGetter<MealCategory?>? category,
    String? searchQuery,
    MealVisibilityFilter? visibilityFilter,
    ValueGetter<String?>? message,
    ValueGetter<String?>? loadError,
  }) {
    final nextMeals = meals ?? this.meals;
    final nextCategory = category != null ? category() : this.category;
    final nextQuery = searchQuery ?? this.searchQuery;
    final nextFilter = visibilityFilter ?? this.visibilityFilter;
    final nextVisible = visible ??
        _filterMeals(nextMeals, nextCategory, nextQuery, nextFilter);
    return MenuManagementState(
      status: status ?? this.status,
      meals: nextMeals,
      visible: nextVisible,
      category: nextCategory,
      searchQuery: nextQuery,
      visibilityFilter: nextFilter,
      message: message != null ? message() : this.message,
      loadError: loadError != null ? loadError() : this.loadError,
    );
  }
}